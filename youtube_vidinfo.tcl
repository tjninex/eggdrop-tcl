### youtube_vidinfo.tcl by ninex (c) 2020-2021

setudef flag ytvidinfo

namespace eval yt_vidinfo { }

## config

set yt_vidinfo::api_url "https://www.youtube.com/watch?v="

## binds

bind pubm - *youtu.be/* yt_vidinfo::print
bind pubm - *youtube.com/watch*v=* yt_vidinfo::print
bind pub mno|mno !youtube yt_vidinfo::toggle_chan

## the procs

proc yt_vidinfo::print {nick uhost hand chan args} {
  set args [cleanarg $args]

  if {[regexp -nocase {(^|[ ]{1})(https{0,1}:\/\/(m\.|www\.){0,1}|www\.)(youtu\.be\/|youtube\.com\/watch[^ ]{1,}v=)([A-Za-z0-9_-]{11})} $args - - - - - y_vid]} {
    
    set event [yt_vidinfo::get_data $y_vid]

    set output ""

    if {[info exists event]} {
      set title [dict get $event "title"]
      set length [yt_vidinfo::duration [dict get $event "length"]]
      set author [dict get $event "author"]
      set views [yt_vidinfo::commify [dict get $event "views"]]
      set upload_date [dict get $event "upload_date"]
      set output "\002You\0030,4Tube\003\002: \"$title\" (uploaded \002$upload_date\002 by \002$author\002) | Length: \002$length\002 | Views: \002$views\002"
    }
    putserv "PRIVMSG $chan :$output"
  }
}

proc yt_vidinfo::get_data {video_id} {
  global yt_vidinfo::api_url

  set w_data [httptk::get_html "${yt_vidinfo::api_url}$video_id"]

  set w_dict ""

  if {[info exists w_data]} {
    set jhtml [regexp {var ytInitialPlayerResponse = (\{.*\});</script><div} $w_data - jdata]

    set ddata [httptk::json2dict $jdata]

    set vid_info [dict get $ddata "videoDetails"]
    set title [dict get $vid_info "title"]
    set length [dict get $vid_info "lengthSeconds"]
    set views [dict get $vid_info "viewCount"]
    set author [dict get $vid_info "author"]
    set upload_date [dict get [dict get [dict get $ddata "microformat"] "playerMicroformatRenderer"] "uploadDate"]

    set w_dict [dict create "title" $title "length" $length "views" $views "author" $author "upload_date" $upload_date]
  }
    
  return $w_dict
}     
   
proc yt_vidinfo::toggle_chan {nick host hand chan text} {
  if {![channel get $chan ytvidinfo] && $text == "on"} {
    catch {channel set $chan +ytvidinfo}
    putserv "notice $nick :YouTube: enabled for $chan"
    putlog "YouTubeVidInfo: script enabled (by $nick for $chan)"
  } elseif {[channel get $chan ytvidinfo] && $text == "off"} {
    catch {channel set $chan -ytvidinfo}
    putserv "notice $nick :YouTube: disabled for $chan"
    putlog "YouTubeVidInfo: script disabled (by $nick for $chan)"
  } else {
    putserv "notice $nick :YouTube: !youtube (on|off) enables or disables script for active channel"
  }
}

proc yt_vidinfo::duration { int_time } {
     set timeList [list]
     foreach div {86400 3600 60 1} mod {0 24 60 60} name {day hr min sec} {
         set n [expr {$int_time / $div}]
         if {$mod > 0} {set n [expr {$n % $mod}]}
         if {$n > 9} {
           lappend timeList "$n"
         } elseif {$n > 0} {
           lappend timeList "0$n"
         } else {
           continue
         }
     }
     if {[llength $timeList] < 2} {linsert $timeList 0 "00"}
     return [join $timeList ":"]
 }

proc yt_vidinfo::commify {num {sep ,}} {
    while {[regsub {^([-+]?\d+)(\d\d\d)} $num "\\1$sep\\2" num]} {}
    return $num
}

putlog "YouTube-VidInfo Titler 0.0.3 by ninex loaded"


