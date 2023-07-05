## weather.tcl by ninex
## Check weather by city or zip

setudef flag weather

set nbt_weather_url "http://api.openweathermap.org/data/2.5/weather?"
set nbt_weather_apikey ""

set nbt_weather_tzurl "http://api.timezonedb.com/v2.1/get-time-zone?format=json&by=position&fields=abbreviation,dst,gmtOffset,zoneName,regionName&key="
set nbt_weather_tzapikey ""

bind pub - !weather pub:nbt_weather
bind pub - !w pub:nbt_weather

proc nbt:weather {nick uhost hand chan args} {
  global nbt_weather_url puburl nbt_weather_apikey nbt_weather_tzurl nbt_weather_tzapikey

  if {![channel get $chan weather]} {
    return
  }

  set args [cleanarg $args]

  set realurl "$args"

  if {$realurl == "{}" || $realurl == ""} {
    putquick "PRIVMSG $chan :\[Weather\] Usage: !weather <zip/location>"
    return
  } elseif {[regexp {^\d{5}$} $realurl]} {
    set realurl "zip=$realurl"
  } else {
    set realurl "q=[url-encode $realurl]"
  }

  set realurl "$nbt_weather_url$realurl&APPID=$nbt_weather_apikey"

  putlog "Weather: $chan $nick $realurl"
  #putlog "Weather: $chan $nick debug"

  set w_data [httptk::get_html $realurl]

  
  if {[info exists w_data]} {
    set w_dict [httptk::json2dict $w_data]
    putlog "w: $w_dict"
    if {[string equal [dict get $w_dict "cod"] "404"]} {
      putquick "PRIVMSG $chan :\[Weather\] City/Location not found by Open Weather Map."
      return
    }
    set w_main [dict get $w_dict "main"]
    set w_sys [dict get $w_dict "sys"]
    set w_id [dict get $w_dict "id"]
    set w_temp [format "%.1f" [expr [dict get $w_main "temp"] - 273.15]]
    set w_temp_f [format "%.1f" [nbt:convert_temp $w_temp "F"]]
    set w_tempmin [format "%.1f" [expr [dict get $w_main "temp_min"] - 273.15]]
    set w_tempmin_f [format "%.1f" [nbt:convert_temp $w_tempmin "F"]]
    set w_tempmax [format "%.1f" [expr [dict get $w_main "temp_max"] - 273.15]]
    set w_tempmax_f [format "%.1f" [nbt:convert_temp $w_tempmax "F"]]
    set w_tempfeel [format "%.1f" [expr [dict get $w_main "feels_like"] - 273.15]]
    set w_tempfeel_f [format "%.1f" [nbt:convert_temp $w_tempfeel "F"]]
    set w_humidity [dict get $w_main "humidity"]
    set w_pressure [dict get $w_main "pressure"]
    set w_country [dict get $w_sys "country"]
    set w_name [dict get $w_dict "name"]
    set w_wind [dict get $w_dict "wind"]
    set w_speed [dict get $w_wind "speed"]
    if {[dict exists $w_wind "deg"]} {
      set w_deg [dict get $w_wind "deg"]
    } else {
      set w_deg "0"
    }
    set w_name [dict get $w_dict "name"]
    set w_clouds [dict get [dict get $w_dict "clouds"] "all"]
    set w_weather ""
    set w_weather_list [dict get $w_dict "weather"]

    set w_lat [dict get [dict get $w_dict "coord"] "lat"]
    set w_lng [dict get [dict get $w_dict "coord"] "lon"]

    set tzurl "$nbt_weather_tzurl$nbt_weather_tzapikey&lat=$w_lat&lng=$w_lng"
    set w_tzinfo [httptk::json2dict [httptk::get_html $tzurl]]

    putlog "$w_tzinfo"

    set w_tzabbr [dict get $w_tzinfo "abbreviation"]
    set w_tzname [dict get $w_tzinfo "zoneName"]

    set w_date [clock format [dict get $w_dict "dt"] -timezone ":$w_tzname" -format "%c"]
    set w_sunrise [clock format [dict get $w_sys "sunrise"] -timezone ":$w_tzname" -format "%r"]
    set w_sunset [clock format [dict get $w_sys "sunset"] -timezone ":$w_tzname" -format "%r"]

    foreach weather $w_weather_list {
        set weather_line [string totitle [dict get $weather "description"]]
        set w_weather "$w_weather$weather_line "
    }

    set w_direction [expr int($w_deg / 45)]
    set w_dir "N"
    switch -- [format %d $w_direction] {
        7 { set w_dir "NW" }
        6 { set w_dir "W" }
        5 { set w_dir "SW" }
        4 { set w_dir "S" }
        3 { set w_dir "SE" }
        2 { set w_dir "E" }
        1 { set w_dir "NE" }
        0 { set w_dir "N" }
        default { set w_dir "N" }
    }

    set w_dir [encoding convertto utf-8 $w_dir]

    set w_color [nbt:temp_color $w_temp_f]
    set w_maxcolor [nbt:temp_color $w_tempmax_f]
    set w_lowcolor [nbt:temp_color $w_tempmin_f]
    set w_feelcolor [nbt:temp_color $w_tempfeel_f]
    set w_wcolor [nbt:wind_color $w_speed]

    set f [open "city.list.json" r]

    while {[gets $f line] != -1} {
        if {[string match "*\"id\": $w_id,*" $line]} {
            break
        }
    }

    close $f

    if {[string length $line] > 0} {
        set w_state [dict get [::httptk::json2dict $line] "state"]
        if {[string length $w_state] > 0} {
            set w_name "$w_name, $w_state"
        }
    }

    set output "PRIVMSG $chan :\[\002$w_name, $w_country\002\] ($w_date $w_tzabbr)"
    set output "$output \002Forecast\002: [string trimright $w_weather]"
    set output "$output \002Temp\002:\003$w_color $w_temp_f\u00b0F ($w_temp\u00b0C)\003"
    set output "$output \002High\002:\003$w_maxcolor $w_tempmax_f\u00b0F ($w_tempmax\u00b0C)\003"
    set output "$output \002Low\002:\003$w_lowcolor $w_tempmin_f\u00b0F ($w_tempmin\u00b0C)\003"
    set output "$output \002Feels Like\002:\003$w_feelcolor $w_tempfeel_f\u00b0F ($w_tempfeel\u00b0C)\003"
    set output "$output \002Humidity\002: $w_humidity%"
    set output "$output \002Pressure\002: $w_pressure hPa"
    set output "$output \002Cloudiness\002: $w_clouds%"
    set output "$output \002Wind\002:\003$w_wcolor $w_speed MPH\003 ($w_dir)"
    set output "$output \002Sunrise\002: $w_sunrise $w_tzabbr \002Sunset\002: $w_sunset $w_tzabbr"

    putquick $output

  } else {
    putquick "PRIVMSG $chan :Weather's gone"
  }

}

proc pub:nbt_weather {nick uhost hand chan args} {
  nbt:weather $nick $uhost $hand $chan $args
}

proc nbt:convert_temp {temp units} {
  if {$units == "C"} {
    return [expr ($temp - 32) / 1.8]
  } elseif {$units == "F"} {
    return [expr ($temp * 1.8) + 32]
  }
}

# white 0 
# black 1 
# blue 2 
# green 3 
# red 4 
# brown 5 
# purple 6 
# orange 7 
# yellow 8 
# light green 9 
# cyan 10 
# light cyan 11 
# light blue 12
# pink 13 
# gray 14 
# light gray 15

proc nbt:wind_color {speed} {

  if {$speed >= 47} {
    return 6
  } elseif {$speed >= 39} {
    return 4
  } elseif {$speed >= 32} {
    return 5
  } elseif {$speed >= 25} {
    return 7
  } elseif {$speed >= 19} {
    return 8
  } elseif {$speed >= 13} {
    return 9
  } elseif {$speed >= 8} {
    return 3
  } elseif {$speed >= 4} {
    return 10
  } elseif {$speed >= 1} {
    return 12
  } else {
    return 2
  }
}

proc nbt:temp_color {tempurature} {
  if {$tempurature >= 90} {
    # red 4
    return 4
  } elseif {$tempurature >= 80} {
    # orange 7
    return 7
  } elseif {$tempurature >= 70} {
    # yellow 8
    return 8
  } elseif {$tempurature >= 60} {
    # light green 9
    return 9
  } elseif {$tempurature >= 50} {
    # green 3
    return 3
  } elseif {$tempurature >= 40} {
    # light blue 12
    return 12
  } elseif {$tempurature >= 32} {
    # blue 2
    return 2
  } else {
    # light cyan 11
    return 11
  }
}

putlog "weather.tcl v0.1.2 by ninex loaded"
