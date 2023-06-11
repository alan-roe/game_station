import encoding.json
import font show *
import font_x11_adobe.sans_14_bold
import font_x11_adobe.sans_10
import font_x11_adobe.sans_14
import color_tft show *
import monitor show Mutex
import mqtt
import net
import net.x509 as net
import ntp
import gpio
import i2c
import http
import http.headers
import certificate_roots
import esp32 
import esp32 show enable_external_wakeup deep_sleep wakeup_cause enable_touchpad_wakeup reset_reason

import pictogrammers_icons.size_20 as icons

import pixel_display.true_color show *
import pixel_display.texture show *

import .env
import .get_display  // Import file in current project, see above.
import .led
import .iic
import .bg
import .bmp
import .bg_b
import .fortnite
import .ui

// Search for icon names on https://materialdesignicons.com/
// (hover over icons to get names).
WMO_4501_ICONS ::= [
  icons.WEATHER_NIGHT,
  icons.WEATHER_SUNNY, // 1
  icons.WEATHER_PARTLY_CLOUDY, // 2
  icons.WEATHER_CLOUDY, // 3
  icons.WEATHER_CLOUDY, // 4
  icons.WEATHER_NIGHT,
  icons.WEATHER_NIGHT,
  icons.WEATHER_NIGHT,
  icons.WEATHER_NIGHT,
  icons.WEATHER_PARTLY_RAINY, // 9
  icons.WEATHER_RAINY,
  icons.WEATHER_LIGHTNING,
  icons.WEATHER_NIGHT,
  icons.WEATHER_SNOWY, // 12
  icons.WEATHER_FOG,
]

// We don't want separate tasks updating the display at the
// same time, so this mutex is used to ensure the tasks only
// have access one at a time.
mqtt_client := mqtt_client_connect

new_msg_alert := false

msg_texture := ?
icon_texture := ?
temperature_texture := ?
time_texture := ?

class MainUi extends Ui:
  display_driver/ColorTft
  touchscreen/TouchScreen
  display_timer := Time.now

  // Buttons
  send_btn := 0
  accept_btn := 0
  reject_btn := 0

  // Windows
  fortnite_stats := 0
  messages := 0

  load_elements:
    sans_14 := Font [sans_14.ASCII]
    sans_10 := Font [sans_10.ASCII, sans_10.LATIN_1_SUPPLEMENT]
    
    bg_color := 0xC5C9FF
    content_color := 0xFDFAE6
    title_color := 0xA2C7E8
    
    window 0 0 480 320 "Jackson's Game Station"
      --title_font = sans_14
      --padding = 5
      --title_bg = title_color
      --content_bg = bg_color
    display.icon (ctx.with --color=BLACK) 460 20 icons.MONITOR

    window 20 35 130 115 "Time/Temp" 
      --content = "21:57\n21°C"
      --content_font = sans_10
      --title_font = sans_14
      --title_bg = title_color
      --content_bg = content_color
      --padding = 5
      --rounded

    window 160 35 300 115 "Actions"
      --title_font = sans_14
      --title_bg = title_color
      --content_bg = content_color
      --padding = 5
      --rounded

    fortnite_stats = (window 20 160 130 140 "Fortnite Stats" 
      --content = "Played: \nWins: \nKills: \nTop 25: "
      --title_font = sans_14
      --title_bg = title_color
      --content_bg = content_color
      --padding = 5
      --rounded)

    messages = window 160 160 300 140 "Messages" 
      --content = "No new messages"
      --title_font = sans_14
      --title_bg = title_color
      --content_bg = content_color
      --padding = 5
      --rounded
    
    send_btn = (button 170 65 80 70 "Send\nInvite"
      --font = sans_14
      --enabled_color = title_color
      --disabled_color = bg_color
      --rounded)
    accept_btn = (button 270 65 80 70 "Accept\nInvite"
      --font = sans_14
      --enabled_color = title_color
      --disabled_color = bg_color
      --rounded)
    reject_btn = (button 370 65 80 70 "Reject\nInvite"
      --font = sans_14
      --enabled_color = title_color
      --disabled_color = bg_color
      --rounded)

  
  constructor .touchscreen/TouchScreen:
    display_driver = load_driver WROOM_16_BIT_LANDSCAPE_SETTINGS
    d := get_display display_driver
    
    super d --landscape
    
    load_elements

  display_enabled= enable/bool:
    if display_enabled_ == enable:
      return

    display_enabled_ = enable
    if enable:
      display_driver.backlight_on
    else: display_driver.backlight_off

  update:
    coords := touchscreen.get_coords
    if display_enabled_ and display_timer.to_now.in_m > 5:
      display_enabled = false

    if coords.s:
      display_timer = Time.now       
      display_enabled = true

    update coords

main:
  if wakeup_cause == esp32.WAKEUP_EXT1:
    mqtt_debug "Woken up from external pin"
    // Chances are that when we just woke up because a pin went high.
    // Give the pin a chance to go low again.
    sleep --ms=1_000
  else:
    mqtt_debug "Woken up for other reasons: $esp32.wakeup_cause"
  
  wpin := reset_reason
  mqtt_debug "reset reason: $(%d wpin)"

  ui := MainUi gt911_int

  mqtt_debug "started program"

  while true:
    ui.update

    if ui.send_btn.released or ui.accept_btn.released:
      play_request
    else if ui.reject_btn.released:
      play_deny

    ui.draw --speed=100

    sleep --ms=20
  // msg_sub msg_texture
  // weather_sub icon_texture temperature_texture 
  // task:: clock_task time_texture
  // task:: watch_touch
  // sleep --ms=5000
  // display.close
  // touch_mutex.do:
  //   gt911_release

  // sleep --ms=5000
  // mqtt_debug "sleeping..."
  // mask :=0
  // mask |= 1 << 21
  // enable_external_wakeup mask false
  // sleep --ms=100
  // deep_sleep (Duration --s=10)

mqtt_debug msg/string:
  mqtt_client.publish "esp32_debug" msg.to_byte_array

new_message_alert_led:
  new_msg_alert = true
  while new_msg_alert:
    Led.blue
    sleep --ms=1000
    Led.off
    sleep --ms=1000

// watch_touch:
//   while true:
//     coord := get_coords
//     x := (480 - coord.y)
//     y := coord.x
//     if coord.s:
//       mqtt_debug "touched, x: $(%d x), y: $(%d y)"
//       if x >= 109 and x <= 189 and y >= 239 and y <= 318:
//         play_request
//         new_msg_alert = false
//         Led.green
//         sleep --ms=1000
//         Led.off
//       else if x >= 292 and x <= 368 and y >= 237 and y <= 314:
//         play_deny
//         new_msg_alert = false
//         Led.red
//         sleep --ms=1000
//         Led.off
//       else: 
//         sleep --ms=1000
//         display_mutex.do:
//           if display_enabled:
//             mqtt_debug "turning off backlight"
//             display_enabled = false
//             display_driver.backlight_off
//           else if not display_enabled:
//             mqtt_debug "turning on backlight"
//             display_enabled = true
//             display_driver.backlight_on
//             sleep --ms=20
//             //display.draw
//         mqtt_debug (FortniteStats FORTNITE_ACC).stringify
//       get_coords
//     sleep --ms=20

mqtt_client_connect -> mqtt.Client:
  network := net.open
  transport := mqtt.TcpTransport network --host=MQTT_HOST
  cl := mqtt.Client --transport=transport
  options := mqtt.SessionOptions
    --client_id=MQTT_CLIENT_ID
  cl.start --options=options
  return cl

play_request:
  mqtt_client.publish "gstation_from" "fa".to_byte_array

play_deny:
  mqtt_client.publish "gstation_from" "fr".to_byte_array

// msg_sub msg_texture/TextTexture:
//   mqtt_client.subscribe "gstation_to":: | topic/string payload/ByteArray |
//     now := (Time.now).local
//     msg := payload.to_string
//     display_mutex.do:
//       task:: new_message_alert_led
//       msg_texture.text = "$now.h:$(%02d now.m): $msg"
//       display.draw

// weather_sub weather_icon/IconTexture temperature_texture/TextTexture:
//   mqtt_client.subscribe "openweather/main/temp":: | topic/string payload/ByteArray |
//     temp := float.parse payload.to_string
//     display_mutex.do:
//       temperature_texture.text = "$(%.1f temp)°C"
//       display.draw
//   mqtt_client.subscribe "openweather/weather/0/icon" :: | topic/string payload/ByteArray |
//     code := int.parse payload.to_string[0..2]
//     if code > 12: code = 13
//     display_mutex.do:
//       weather_icon.icon = WMO_4501_ICONS[code]
//       display.draw

// clock_task time_texture:
//   while true:
//     now := (Time.now).local
//     display_mutex.do:
//       // H:MM or HH:MM depending on time of day.
//       time_texture.text = "$now.h:$(%02d now.m)"
//       display.draw
//     // Sleep this task until the next whole minute.
//     sleep_time := 60 - now.s
//     sleep --ms=sleep_time*1000
