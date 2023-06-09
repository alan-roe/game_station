import http
import http.headers
import net
import encoding.json
import certificate_roots

import .env

class FortniteStats:
  static HOST ::= "fortniteapi.io"
  static PATH ::= "/v1/stats?account="
  level/int
  kills/int
  wins/int
  played/int
  top25/int

  constructor id/string:
    client := http.Client.tls (net.open)
      --root_certificates=[certificate_roots.BALTIMORE_CYBERTRUST_ROOT]
    header := headers.Headers
    header.set "Authorization" FORTNITE_API_AUTH
    response := client.get HOST (PATH + id)
      --headers=header

    data := json.decode_stream response.body
    level = (data.get "account").get "level"
    global := (data.get "global_stats")
    duo := (global.get "duo")
    solo := (global.get "solo")

    kills = (solo.get "kills") + (duo.get "kills")
    wins = (solo.get "placetop1") + (duo.get "placetop1")
    played = (solo.get "matchesplayed") + (duo.get "matchesplayed")
    top25 = (get_top25_ solo) + (get_top25_ duo)

    client.close
  
  stringify -> string:
    return "Level: $level\nPlayed: $played\nWins: $wins\nKills: $kills\nTop 25: $top25"

  static get_top25_ xs -> int:
    return ((xs.get "placetop3") + (xs.get "placetop5") + (xs.get "placetop6") + (xs.get "placetop10") + (xs.get "placetop12") + (xs.get "placetop25"))
