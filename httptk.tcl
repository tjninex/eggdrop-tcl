## httptk.tcl - useful http related functions
## -ninex

package require http
package require json

namespace eval httptk { }

set httptk::timeout 15000

set httptk::use_ssl 1

set reqcert yes:no

## ssl
if {$httptk::use_ssl} {
  package require tls
  scan $reqcert {%[^:]:%s} r1 r2
  if {$r1 == "yes"} {set r1 1} {set r1 0}
  if {$r2 == "yes"} {set r2 1} {set r2 0}
  set ssl [list ::tls::socket -request $r1 -require $r2]
  ::http::register https 443 $ssl
}

## the rest

# Gets the HTML from a webpage
proc httptk::get_html {url {useragent "Lynx/2.8.8rel.2 libwww-FM/2.14 SSL-MM/1.4.1 OpenSSL/1.0.1u"}} {
    if {[catch {package require http}]} {
            putlog "HTTPToolkit: package http 2.5 or above required"
    } else {
        ## [list {HTTPToolkit} {1.2}]
        #set tsta [::http::config -useragent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:74.0) Gecko/20100101 Firefox/74.0"]
        ::http::config -useragent $useragent
        if {[catch {set http_con [::http::geturl "$url" -timeout $httptk::timeout]}]} {
                putlog "HTTPToolkit: connection error (host not found / reachable) => $url"
                return
        } elseif {[::http::status $http_con] == "ok"} {
                set http_data [::http::data $http_con]
                catch {::http::cleanup $http_con}
        } else {
                putlog "HTTPToolkit: connection error (time out / no data received) => $url"
                catch {::http::cleanup $http_con}
                return
        }
    }
    
    return $http_data   
}

proc httptk::map_html {text} {
    set text [string map -nocase [list {&quot;} {"} {&amp;} {&} {&#x201C;} {"} {&#x201D;} {"} {&amp;} {&} {&lt;} {<} {&gt;} {>} {&#8216;} {'} {&#8217;} {'} {&#x28;} {(} {&#x29;} {)} {&laquo;} {"} {&ldquo;} {"} {&rdquo;} {"} {&#x22;} {"} {&#x27;} {'} {&#039;} {'} {&#39;} {'} {&#8211;} {-} {&#10;} { } {&apos;} {'} {&#8220;} {"} {&#8221;} {"}] $text]
    # remove any non-matched chars
    set text [regsub -all {&#x?([0-9a-zA-Z]{1,6});} $text {}]
    return $text
}

# from Antender @ http://wiki.tcl.tk/13419
proc httptk::json2dict {JSONtext} {
    return [string range [
      string trim [
        string trimleft [
            string map {\t {} \n {} \r {} , { } : { } \[ \{ \] \}} $JSONtext
            ] {\uFEFF}
        ]
    ] 1 end-1]
}

# from http://wiki.tcl.tk/14144
proc url-encode {string} {

    variable map
    variable alphanumeric a-zA-Z0-9
    for {set i 0} {$i <= 256} {incr i} {
        set c [format %c $i]
        if {![string match \[$alphanumeric\] $c]} {
            set map($c) %[format %.2x $i]
        }
    }
    # These are handled specially
    array set map { " " + \n %0d%0a }

    # The spec says: "non-alphanumeric characters are replaced by '%HH'"
    # 1 leave alphanumerics characters alone
    # 2 Convert every other character to an array lookup
    # 3 Escape constructs that are "special" to the tcl parser
    # 4 "subst" the result, doing all the array substitutions

    regsub -all \[^$alphanumeric\] $string {$map(&)} string
    # This quotes cases like $map([) or $map($) => $map(\[) ...
    regsub -all {[][{})\\]\)} $string {\\&} string
    return [subst -nocommand $string]
}                 

proc url-decode {str} {
    # rewrite "+" back to space
    # protect \ from quoting another '\'
    set str [string map [list + { } "\\" "\\\\"] $str]

    # prepare to process all %-escapes
    regsub -all -- {%([A-Fa-f0-9][A-Fa-f0-9])} $str {\\u00\1} str

    # process \u unicode mapped chars
    return [subst -novar -nocommand $str]
}

putlog "httptk.tcl v0.2 loaded"
