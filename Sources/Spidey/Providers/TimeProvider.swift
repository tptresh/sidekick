import AppKit

// "time in tokyo": current time in any city macOS knows a time zone for.
enum TimeProvider {
    struct Match {
        let identifier: String
        let label: String
    }

    // Places people type that the time zone database does not name directly:
    // "new delhi" lives in Asia/Kolkata, "hk" in Asia/Hong_Kong, and country
    // names never appear in an identifier at all.
    struct City {
        let label: String
        let identifier: String
        let names: [String]
    }

    // The order here breaks ties, so the better known place comes first.
    struct Country {
        let name: String
        let names: [String]
        let zones: [String]
    }

    static let cities: [City] = [
        City(label: "New York", identifier: "America/New_York",
             names: ["new york", "new york city", "nyc", "manhattan", "brooklyn", "east coast"]),
        City(label: "Boston", identifier: "America/New_York", names: ["boston"]),
        City(label: "Washington DC", identifier: "America/New_York",
             names: ["washington", "washington dc", "dc"]),
        City(label: "Philadelphia", identifier: "America/New_York", names: ["philadelphia", "philly"]),
        City(label: "Atlanta", identifier: "America/New_York", names: ["atlanta"]),
        City(label: "Miami", identifier: "America/New_York", names: ["miami", "florida", "orlando"]),
        City(label: "Detroit", identifier: "America/Detroit", names: ["detroit"]),
        City(label: "Toronto", identifier: "America/Toronto", names: ["toronto"]),
        City(label: "Ottawa", identifier: "America/Toronto", names: ["ottawa"]),
        City(label: "Montreal", identifier: "America/Toronto", names: ["montreal"]),
        City(label: "Chicago", identifier: "America/Chicago", names: ["chicago"]),
        City(label: "Houston", identifier: "America/Chicago", names: ["houston"]),
        City(label: "Dallas", identifier: "America/Chicago", names: ["dallas", "fort worth"]),
        City(label: "Austin", identifier: "America/Chicago", names: ["austin", "texas"]),
        City(label: "Minneapolis", identifier: "America/Chicago", names: ["minneapolis"]),
        City(label: "New Orleans", identifier: "America/Chicago", names: ["new orleans"]),
        City(label: "Denver", identifier: "America/Denver", names: ["denver", "colorado"]),
        City(label: "Salt Lake City", identifier: "America/Denver", names: ["salt lake city", "slc", "utah"]),
        City(label: "Phoenix", identifier: "America/Phoenix", names: ["phoenix", "arizona"]),
        City(label: "Los Angeles", identifier: "America/Los_Angeles",
             names: ["los angeles", "la", "hollywood"]),
        City(label: "San Diego", identifier: "America/Los_Angeles", names: ["san diego"]),
        City(label: "Las Vegas", identifier: "America/Los_Angeles", names: ["las vegas", "vegas"]),
        City(label: "San Francisco", identifier: "America/Los_Angeles",
             names: ["san francisco", "sf", "bay area", "silicon valley", "palo alto", "cupertino"]),
        City(label: "Seattle", identifier: "America/Los_Angeles", names: ["seattle", "west coast"]),
        City(label: "Portland", identifier: "America/Los_Angeles", names: ["portland", "oregon"]),
        City(label: "Vancouver", identifier: "America/Vancouver", names: ["vancouver"]),

        City(label: "Honolulu", identifier: "Pacific/Honolulu", names: ["honolulu", "hawaii"]),

        City(label: "Anchorage", identifier: "America/Anchorage", names: ["anchorage", "alaska"]),
        City(label: "Mexico City", identifier: "America/Mexico_City", names: ["mexico city", "cdmx"]),
        City(label: "Sao Paulo", identifier: "America/Sao_Paulo", names: ["sao paulo", "brasilia"]),
        City(label: "Rio de Janeiro", identifier: "America/Sao_Paulo", names: ["rio", "rio de janeiro"]),
        City(label: "Buenos Aires", identifier: "America/Argentina/Buenos_Aires",
             names: ["buenos aires"]),
        City(label: "Santiago", identifier: "America/Santiago", names: ["santiago"]),
        City(label: "Lima", identifier: "America/Lima", names: ["lima"]),
        City(label: "Bogota", identifier: "America/Bogota", names: ["bogota"]),

        City(label: "London", identifier: "Europe/London",
             names: ["london", "england"]),
        City(label: "Edinburgh", identifier: "Europe/London", names: ["edinburgh", "scotland", "glasgow"]),
        City(label: "Manchester", identifier: "Europe/London",
             names: ["manchester", "birmingham", "liverpool"]),
        City(label: "Cardiff", identifier: "Europe/London", names: ["cardiff", "wales"]),
        City(label: "Dublin", identifier: "Europe/Dublin", names: ["dublin"]),
        City(label: "Paris", identifier: "Europe/Paris", names: ["paris"]),
        City(label: "Lyon", identifier: "Europe/Paris", names: ["lyon", "marseille", "nice", "bordeaux"]),
        City(label: "Berlin", identifier: "Europe/Berlin", names: ["berlin"]),
        City(label: "Munich", identifier: "Europe/Berlin", names: ["munich", "muenchen"]),
        City(label: "Frankfurt", identifier: "Europe/Berlin", names: ["frankfurt"]),
        City(label: "Hamburg", identifier: "Europe/Berlin", names: ["hamburg", "cologne", "dusseldorf"]),
        City(label: "Amsterdam", identifier: "Europe/Amsterdam",
             names: ["amsterdam", "rotterdam"]),
        City(label: "Brussels", identifier: "Europe/Brussels", names: ["brussels"]),
        City(label: "Madrid", identifier: "Europe/Madrid", names: ["madrid"]),
        City(label: "Barcelona", identifier: "Europe/Madrid", names: ["barcelona", "valencia", "seville"]),
        City(label: "Lisbon", identifier: "Europe/Lisbon", names: ["lisbon", "porto"]),
        City(label: "Rome", identifier: "Europe/Rome", names: ["rome"]),
        City(label: "Milan", identifier: "Europe/Rome", names: ["milan", "milano"]),
        City(label: "Naples", identifier: "Europe/Rome", names: ["naples", "venice", "florence", "turin"]),
        City(label: "Zurich", identifier: "Europe/Zurich", names: ["zurich", "basel", "bern"]),
        City(label: "Geneva", identifier: "Europe/Zurich", names: ["geneva"]),
        City(label: "Vienna", identifier: "Europe/Vienna", names: ["vienna"]),
        City(label: "Stockholm", identifier: "Europe/Stockholm", names: ["stockholm"]),
        City(label: "Oslo", identifier: "Europe/Oslo", names: ["oslo"]),
        City(label: "Copenhagen", identifier: "Europe/Copenhagen", names: ["copenhagen"]),
        City(label: "Helsinki", identifier: "Europe/Helsinki", names: ["helsinki"]),
        City(label: "Warsaw", identifier: "Europe/Warsaw", names: ["warsaw", "krakow"]),
        City(label: "Prague", identifier: "Europe/Prague", names: ["prague"]),
        City(label: "Budapest", identifier: "Europe/Budapest", names: ["budapest"]),
        City(label: "Athens", identifier: "Europe/Athens", names: ["athens"]),
        City(label: "Istanbul", identifier: "Europe/Istanbul", names: ["istanbul", "ankara"]),
        City(label: "Bucharest", identifier: "Europe/Bucharest", names: ["bucharest"]),
        City(label: "Moscow", identifier: "Europe/Moscow", names: ["moscow"]),
        City(label: "St Petersburg", identifier: "Europe/Moscow", names: ["st petersburg", "saint petersburg"]),
        City(label: "Kyiv", identifier: "Europe/Kyiv", names: ["kyiv", "kiev"]),

        City(label: "Reykjavik", identifier: "Atlantic/Reykjavik", names: ["reykjavik"]),

        City(label: "Dubai", identifier: "Asia/Dubai",
             names: ["dubai"]),
        City(label: "Abu Dhabi", identifier: "Asia/Dubai", names: ["abu dhabi"]),
        City(label: "Doha", identifier: "Asia/Qatar", names: ["doha"]),
        City(label: "Riyadh", identifier: "Asia/Riyadh", names: ["riyadh"]),
        City(label: "Jeddah", identifier: "Asia/Riyadh", names: ["jeddah", "mecca", "makkah"]),
        City(label: "Tel Aviv", identifier: "Asia/Jerusalem", names: ["tel aviv"]),
        City(label: "Jerusalem", identifier: "Asia/Jerusalem", names: ["jerusalem"]),
        City(label: "Tehran", identifier: "Asia/Tehran", names: ["tehran"]),

        City(label: "Cairo", identifier: "Africa/Cairo", names: ["cairo"]),
        City(label: "Lagos", identifier: "Africa/Lagos", names: ["lagos", "abuja"]),
        City(label: "Nairobi", identifier: "Africa/Nairobi", names: ["nairobi"]),
        City(label: "Johannesburg", identifier: "Africa/Johannesburg",
             names: ["johannesburg", "pretoria", "durban"]),
        City(label: "Cape Town", identifier: "Africa/Johannesburg", names: ["cape town", "capetown"]),
        City(label: "Casablanca", identifier: "Africa/Casablanca",
             names: ["casablanca", "marrakech"]),
        City(label: "Accra", identifier: "Africa/Accra", names: ["accra"]),
        City(label: "Addis Ababa", identifier: "Africa/Addis_Ababa", names: ["addis ababa"]),

        City(label: "New Delhi", identifier: "Asia/Kolkata",
             names: ["new delhi", "delhi", "gurgaon", "gurugram", "noida"]),
        City(label: "Mumbai", identifier: "Asia/Kolkata", names: ["mumbai", "bombay"]),
        City(label: "Bengaluru", identifier: "Asia/Kolkata", names: ["bengaluru", "bangalore"]),
        City(label: "Hyderabad", identifier: "Asia/Kolkata", names: ["hyderabad"]),
        City(label: "Chennai", identifier: "Asia/Kolkata", names: ["chennai", "madras"]),
        City(label: "Pune", identifier: "Asia/Kolkata", names: ["pune"]),
        City(label: "Karachi", identifier: "Asia/Karachi", names: ["karachi"]),
        City(label: "Lahore", identifier: "Asia/Karachi", names: ["lahore", "islamabad"]),
        City(label: "Dhaka", identifier: "Asia/Dhaka", names: ["dhaka"]),
        City(label: "Colombo", identifier: "Asia/Colombo", names: ["colombo"]),
        City(label: "Kathmandu", identifier: "Asia/Kathmandu", names: ["kathmandu"]),
        City(label: "Beijing", identifier: "Asia/Shanghai", names: ["beijing", "peking"]),
        City(label: "Shanghai", identifier: "Asia/Shanghai", names: ["shanghai"]),
        City(label: "Shenzhen", identifier: "Asia/Shanghai", names: ["shenzhen", "guangzhou"]),
        City(label: "Hong Kong", identifier: "Asia/Hong_Kong", names: ["hong kong", "hk", "hkg", "hongkong"]),
        City(label: "Macau", identifier: "Asia/Macau", names: ["macau", "macao"]),
        City(label: "Taipei", identifier: "Asia/Taipei", names: ["taipei"]),
        City(label: "Tokyo", identifier: "Asia/Tokyo", names: ["tokyo"]),
        City(label: "Osaka", identifier: "Asia/Tokyo", names: ["osaka", "kyoto", "yokohama"]),
        City(label: "Seoul", identifier: "Asia/Seoul", names: ["seoul", "busan"]),
        City(label: "Singapore", identifier: "Asia/Singapore", names: ["singapore", "sg", "sgp"]),
        City(label: "Kuala Lumpur", identifier: "Asia/Kuala_Lumpur", names: ["kuala lumpur", "kl"]),
        City(label: "Jakarta", identifier: "Asia/Jakarta", names: ["jakarta"]),
        City(label: "Bali", identifier: "Asia/Makassar", names: ["bali", "denpasar"]),
        City(label: "Bangkok", identifier: "Asia/Bangkok", names: ["bangkok"]),
        City(label: "Phuket", identifier: "Asia/Bangkok", names: ["phuket", "chiang mai"]),
        City(label: "Ho Chi Minh City", identifier: "Asia/Ho_Chi_Minh",
             names: ["ho chi minh", "ho chi minh city", "saigon"]),
        City(label: "Hanoi", identifier: "Asia/Ho_Chi_Minh", names: ["hanoi"]),
        City(label: "Manila", identifier: "Asia/Manila", names: ["manila"]),
        City(label: "Almaty", identifier: "Asia/Almaty", names: ["almaty"]),
        City(label: "Tashkent", identifier: "Asia/Tashkent", names: ["tashkent"]),

        City(label: "Sydney", identifier: "Australia/Sydney", names: ["sydney", "canberra"]),
        City(label: "Melbourne", identifier: "Australia/Melbourne", names: ["melbourne"]),
        City(label: "Brisbane", identifier: "Australia/Brisbane",
             names: ["brisbane", "queensland", "gold coast"]),
        City(label: "Perth", identifier: "Australia/Perth", names: ["perth"]),
        City(label: "Adelaide", identifier: "Australia/Adelaide", names: ["adelaide"]),

        City(label: "Auckland", identifier: "Pacific/Auckland", names: ["auckland"]),
        City(label: "Wellington", identifier: "Pacific/Auckland", names: ["wellington", "christchurch"]),
        City(label: "Fiji", identifier: "Pacific/Fiji", names: ["fiji", "suva"]),

        City(label: "UTC", identifier: "UTC", names: ["utc", "gmt", "zulu", "coordinated universal time"]),
    ]

    // Every country the time zone database knows, so naming any of them
    // answers. Built from its iso3166.tab and zone.tab. A country gets more
    // than one zone only where a single time would misinform: the capital's
    // zone comes first, and an offshore island on its own offset is left to
    // whoever names the island.
    static let countries: [Country] = [
        Country(name: "Andorra", names: ["andorra"], zones: ["Europe/Andorra"]),
        Country(name: "United Arab Emirates", names: ["united arab emirates", "uae", "emirates"],
                zones: ["Asia/Dubai"]),
        Country(name: "Afghanistan", names: ["afghanistan"], zones: ["Asia/Kabul"]),
        Country(name: "Antigua and Barbuda", names: ["antigua and barbuda", "antigua", "antigua barbuda"],
                zones: ["America/Antigua"]),
        Country(name: "Anguilla", names: ["anguilla"], zones: ["America/Anguilla"]),
        Country(name: "Albania", names: ["albania"], zones: ["Europe/Tirane"]),
        Country(name: "Armenia", names: ["armenia"], zones: ["Asia/Yerevan"]),
        Country(name: "Angola", names: ["angola"], zones: ["Africa/Luanda"]),
        Country(name: "Antarctica", names: ["antarctica"], zones: ["Antarctica/McMurdo"]),
        Country(name: "Argentina", names: ["argentina"], zones: ["America/Argentina/Buenos_Aires"]),
        Country(name: "American Samoa", names: ["american samoa", "samoa american"],
                zones: ["Pacific/Pago_Pago"]),
        Country(name: "Austria", names: ["austria"], zones: ["Europe/Vienna"]),
        Country(name: "Australia", names: ["australia"],
                zones: ["Australia/Sydney", "Australia/Adelaide", "Australia/Perth"]),
        Country(name: "Aruba", names: ["aruba"], zones: ["America/Aruba"]),
        Country(name: "Åland Islands", names: ["aland islands"], zones: ["Europe/Mariehamn"]),
        Country(name: "Azerbaijan", names: ["azerbaijan"], zones: ["Asia/Baku"]),
        Country(name: "Bosnia and Herzegovina",
                names: ["bosnia and herzegovina", "bosnia", "bosnia herzegovina"],
                zones: ["Europe/Sarajevo"]),
        Country(name: "Barbados", names: ["barbados"], zones: ["America/Barbados"]),
        Country(name: "Bangladesh", names: ["bangladesh"], zones: ["Asia/Dhaka"]),
        Country(name: "Belgium", names: ["belgium"], zones: ["Europe/Brussels"]),
        Country(name: "Burkina Faso", names: ["burkina faso"], zones: ["Africa/Ouagadougou"]),
        Country(name: "Bulgaria", names: ["bulgaria"], zones: ["Europe/Sofia"]),
        Country(name: "Bahrain", names: ["bahrain"], zones: ["Asia/Bahrain"]),
        Country(name: "Burundi", names: ["burundi"], zones: ["Africa/Bujumbura"]),
        Country(name: "Benin", names: ["benin"], zones: ["Africa/Porto-Novo"]),
        Country(name: "St Barthelemy", names: ["st barthelemy"], zones: ["America/St_Barthelemy"]),
        Country(name: "Bermuda", names: ["bermuda"], zones: ["Atlantic/Bermuda"]),
        Country(name: "Brunei", names: ["brunei"], zones: ["Asia/Brunei"]),
        Country(name: "Bolivia", names: ["bolivia"], zones: ["America/La_Paz"]),
        Country(name: "Caribbean NL", names: ["caribbean nl"], zones: ["America/Kralendijk"]),
        Country(name: "Brazil", names: ["brazil"], zones: ["America/Sao_Paulo", "America/Manaus"]),
        Country(name: "Bahamas", names: ["bahamas"], zones: ["America/Nassau"]),
        Country(name: "Bhutan", names: ["bhutan"], zones: ["Asia/Thimphu"]),
        Country(name: "Botswana", names: ["botswana"], zones: ["Africa/Gaborone"]),
        Country(name: "Belarus", names: ["belarus"], zones: ["Europe/Minsk"]),
        Country(name: "Belize", names: ["belize"], zones: ["America/Belize"]),
        Country(name: "Canada", names: ["canada"],
                zones: ["America/Toronto", "America/Winnipeg", "America/Vancouver"]),
        Country(name: "Cocos Islands", names: ["cocos islands", "keeling islands", "cocos keeling islands"],
                zones: ["Indian/Cocos"]),
        Country(name: "DR Congo",
                names: ["dr congo", "drc", "democratic republic of the congo", "congo kinshasa", "zaire",
                        "congo dem rep"],
                zones: ["Africa/Kinshasa"]),
        Country(name: "Central African Republic", names: ["central african republic", "central african rep"],
                zones: ["Africa/Bangui"]),
        Country(name: "Congo", names: ["congo", "republic of the congo", "congo brazzaville", "congo rep"],
                zones: ["Africa/Brazzaville"]),
        Country(name: "Switzerland", names: ["switzerland"], zones: ["Europe/Zurich"]),
        Country(name: "Cote d'Ivoire", names: ["cote d ivoire", "ivory coast"], zones: ["Africa/Abidjan"]),
        Country(name: "Cook Islands", names: ["cook islands"], zones: ["Pacific/Rarotonga"]),
        Country(name: "Chile", names: ["chile"], zones: ["America/Santiago"]),
        Country(name: "Cameroon", names: ["cameroon"], zones: ["Africa/Douala"]),
        Country(name: "China", names: ["china"], zones: ["Asia/Shanghai"]),
        Country(name: "Colombia", names: ["colombia"], zones: ["America/Bogota"]),
        Country(name: "Costa Rica", names: ["costa rica"], zones: ["America/Costa_Rica"]),
        Country(name: "Cuba", names: ["cuba"], zones: ["America/Havana"]),
        Country(name: "Cape Verde", names: ["cape verde", "cabo verde"], zones: ["Atlantic/Cape_Verde"]),
        Country(name: "Curaçao", names: ["curacao"], zones: ["America/Curacao"]),
        Country(name: "Christmas Island", names: ["christmas island"], zones: ["Indian/Christmas"]),
        Country(name: "Cyprus", names: ["cyprus"], zones: ["Asia/Nicosia"]),
        Country(name: "Czech Republic", names: ["czech republic", "czechia"], zones: ["Europe/Prague"]),
        Country(name: "Germany", names: ["germany"], zones: ["Europe/Berlin"]),
        Country(name: "Djibouti", names: ["djibouti"], zones: ["Africa/Djibouti"]),
        Country(name: "Denmark", names: ["denmark"], zones: ["Europe/Copenhagen"]),
        Country(name: "Dominica", names: ["dominica"], zones: ["America/Dominica"]),
        Country(name: "Dominican Republic", names: ["dominican republic"], zones: ["America/Santo_Domingo"]),
        Country(name: "Algeria", names: ["algeria"], zones: ["Africa/Algiers"]),
        Country(name: "Ecuador", names: ["ecuador"], zones: ["America/Guayaquil"]),
        Country(name: "Estonia", names: ["estonia"], zones: ["Europe/Tallinn"]),
        Country(name: "Egypt", names: ["egypt"], zones: ["Africa/Cairo"]),
        Country(name: "Western Sahara", names: ["western sahara"], zones: ["Africa/El_Aaiun"]),
        Country(name: "Eritrea", names: ["eritrea"], zones: ["Africa/Asmara"]),
        Country(name: "Spain", names: ["spain"], zones: ["Europe/Madrid"]),
        Country(name: "Ethiopia", names: ["ethiopia"], zones: ["Africa/Addis_Ababa"]),
        Country(name: "Finland", names: ["finland"], zones: ["Europe/Helsinki"]),
        Country(name: "Fiji", names: ["fiji"], zones: ["Pacific/Fiji"]),
        Country(name: "Falkland Islands", names: ["falkland islands"], zones: ["Atlantic/Stanley"]),
        Country(name: "Micronesia", names: ["micronesia", "federated states of micronesia"],
                zones: ["Pacific/Pohnpei"]),
        Country(name: "Faroe Islands", names: ["faroe islands"], zones: ["Atlantic/Faroe"]),
        Country(name: "France", names: ["france"], zones: ["Europe/Paris"]),
        Country(name: "Gabon", names: ["gabon"], zones: ["Africa/Libreville"]),
        Country(name: "United Kingdom",
                names: ["united kingdom", "uk", "britain", "great britain", "britain uk"],
                zones: ["Europe/London"]),
        Country(name: "Grenada", names: ["grenada"], zones: ["America/Grenada"]),
        Country(name: "Georgia", names: ["georgia"], zones: ["Asia/Tbilisi"]),
        Country(name: "French Guiana", names: ["french guiana"], zones: ["America/Cayenne"]),
        Country(name: "Guernsey", names: ["guernsey"], zones: ["Europe/Guernsey"]),
        Country(name: "Ghana", names: ["ghana"], zones: ["Africa/Accra"]),
        Country(name: "Gibraltar", names: ["gibraltar"], zones: ["Europe/Gibraltar"]),
        Country(name: "Greenland", names: ["greenland"], zones: ["America/Nuuk"]),
        Country(name: "Gambia", names: ["gambia"], zones: ["Africa/Banjul"]),
        Country(name: "Guinea", names: ["guinea"], zones: ["Africa/Conakry"]),
        Country(name: "Guadeloupe", names: ["guadeloupe"], zones: ["America/Guadeloupe"]),
        Country(name: "Equatorial Guinea", names: ["equatorial guinea"], zones: ["Africa/Malabo"]),
        Country(name: "Greece", names: ["greece"], zones: ["Europe/Athens"]),
        Country(name: "South Georgia",
                names: ["south georgia", "south sandwich islands", "south georgia the south sandwich islands"],
                zones: ["Atlantic/South_Georgia"]),
        Country(name: "Guatemala", names: ["guatemala"], zones: ["America/Guatemala"]),
        Country(name: "Guam", names: ["guam"], zones: ["Pacific/Guam"]),
        Country(name: "Guinea-Bissau", names: ["guinea bissau"], zones: ["Africa/Bissau"]),
        Country(name: "Guyana", names: ["guyana"], zones: ["America/Guyana"]),
        Country(name: "Hong Kong", names: ["hong kong"], zones: ["Asia/Hong_Kong"]),
        Country(name: "Honduras", names: ["honduras"], zones: ["America/Tegucigalpa"]),
        Country(name: "Croatia", names: ["croatia"], zones: ["Europe/Zagreb"]),
        Country(name: "Haiti", names: ["haiti"], zones: ["America/Port-au-Prince"]),
        Country(name: "Hungary", names: ["hungary"], zones: ["Europe/Budapest"]),
        Country(name: "Indonesia", names: ["indonesia"],
                zones: ["Asia/Jakarta", "Asia/Makassar", "Asia/Jayapura"]),
        Country(name: "Ireland", names: ["ireland"], zones: ["Europe/Dublin"]),
        Country(name: "Israel", names: ["israel"], zones: ["Asia/Jerusalem"]),
        Country(name: "Isle of Man", names: ["isle of man"], zones: ["Europe/Isle_of_Man"]),
        Country(name: "India", names: ["india"], zones: ["Asia/Kolkata"]),
        Country(name: "British Indian Ocean Territory", names: ["british indian ocean territory"],
                zones: ["Indian/Chagos"]),
        Country(name: "Iraq", names: ["iraq"], zones: ["Asia/Baghdad"]),
        Country(name: "Iran", names: ["iran"], zones: ["Asia/Tehran"]),
        Country(name: "Iceland", names: ["iceland"], zones: ["Atlantic/Reykjavik"]),
        Country(name: "Italy", names: ["italy"], zones: ["Europe/Rome"]),
        Country(name: "Jersey", names: ["jersey"], zones: ["Europe/Jersey"]),
        Country(name: "Jamaica", names: ["jamaica"], zones: ["America/Jamaica"]),
        Country(name: "Jordan", names: ["jordan"], zones: ["Asia/Amman"]),
        Country(name: "Japan", names: ["japan"], zones: ["Asia/Tokyo"]),
        Country(name: "Kenya", names: ["kenya"], zones: ["Africa/Nairobi"]),
        Country(name: "Kyrgyzstan", names: ["kyrgyzstan"], zones: ["Asia/Bishkek"]),
        Country(name: "Cambodia", names: ["cambodia"], zones: ["Asia/Phnom_Penh"]),
        Country(name: "Kiribati", names: ["kiribati"], zones: ["Pacific/Tarawa"]),
        Country(name: "Comoros", names: ["comoros"], zones: ["Indian/Comoro"]),
        Country(name: "St Kitts and Nevis",
                names: ["st kitts and nevis", "saint kitts and nevis", "st kitts nevis"],
                zones: ["America/St_Kitts"]),
        Country(name: "North Korea", names: ["north korea", "korea north"], zones: ["Asia/Pyongyang"]),
        Country(name: "South Korea", names: ["south korea", "korea", "korea south"], zones: ["Asia/Seoul"]),
        Country(name: "Kuwait", names: ["kuwait"], zones: ["Asia/Kuwait"]),
        Country(name: "Cayman Islands", names: ["cayman islands"], zones: ["America/Cayman"]),
        Country(name: "Kazakhstan", names: ["kazakhstan"], zones: ["Asia/Almaty"]),
        Country(name: "Laos", names: ["laos", "lao"], zones: ["Asia/Vientiane"]),
        Country(name: "Lebanon", names: ["lebanon"], zones: ["Asia/Beirut"]),
        Country(name: "St Lucia", names: ["st lucia"], zones: ["America/St_Lucia"]),
        Country(name: "Liechtenstein", names: ["liechtenstein"], zones: ["Europe/Vaduz"]),
        Country(name: "Sri Lanka", names: ["sri lanka"], zones: ["Asia/Colombo"]),
        Country(name: "Liberia", names: ["liberia"], zones: ["Africa/Monrovia"]),
        Country(name: "Lesotho", names: ["lesotho"], zones: ["Africa/Maseru"]),
        Country(name: "Lithuania", names: ["lithuania"], zones: ["Europe/Vilnius"]),
        Country(name: "Luxembourg", names: ["luxembourg"], zones: ["Europe/Luxembourg"]),
        Country(name: "Latvia", names: ["latvia"], zones: ["Europe/Riga"]),
        Country(name: "Libya", names: ["libya"], zones: ["Africa/Tripoli"]),
        Country(name: "Morocco", names: ["morocco"], zones: ["Africa/Casablanca"]),
        Country(name: "Monaco", names: ["monaco"], zones: ["Europe/Monaco"]),
        Country(name: "Moldova", names: ["moldova"], zones: ["Europe/Chisinau"]),
        Country(name: "Montenegro", names: ["montenegro"], zones: ["Europe/Podgorica"]),
        Country(name: "St Martin", names: ["st martin", "saint martin", "st martin french"],
                zones: ["America/Marigot"]),
        Country(name: "Madagascar", names: ["madagascar"], zones: ["Indian/Antananarivo"]),
        Country(name: "Marshall Islands", names: ["marshall islands"], zones: ["Pacific/Majuro"]),
        Country(name: "North Macedonia", names: ["north macedonia", "macedonia"], zones: ["Europe/Skopje"]),
        Country(name: "Mali", names: ["mali"], zones: ["Africa/Bamako"]),
        Country(name: "Myanmar", names: ["myanmar", "burma", "myanmar burma"], zones: ["Asia/Yangon"]),
        Country(name: "Mongolia", names: ["mongolia"], zones: ["Asia/Ulaanbaatar"]),
        Country(name: "Macau", names: ["macau", "macao"], zones: ["Asia/Macau"]),
        Country(name: "Northern Mariana Islands", names: ["northern mariana islands"],
                zones: ["Pacific/Saipan"]),
        Country(name: "Martinique", names: ["martinique"], zones: ["America/Martinique"]),
        Country(name: "Mauritania", names: ["mauritania"], zones: ["Africa/Nouakchott"]),
        Country(name: "Montserrat", names: ["montserrat"], zones: ["America/Montserrat"]),
        Country(name: "Malta", names: ["malta"], zones: ["Europe/Malta"]),
        Country(name: "Mauritius", names: ["mauritius"], zones: ["Indian/Mauritius"]),
        Country(name: "Maldives", names: ["maldives"], zones: ["Indian/Maldives"]),
        Country(name: "Malawi", names: ["malawi"], zones: ["Africa/Blantyre"]),
        Country(name: "Mexico", names: ["mexico"], zones: ["America/Mexico_City", "America/Tijuana"]),
        Country(name: "Malaysia", names: ["malaysia"], zones: ["Asia/Kuala_Lumpur"]),
        Country(name: "Mozambique", names: ["mozambique"], zones: ["Africa/Maputo"]),
        Country(name: "Namibia", names: ["namibia"], zones: ["Africa/Windhoek"]),
        Country(name: "New Caledonia", names: ["new caledonia"], zones: ["Pacific/Noumea"]),
        Country(name: "Niger", names: ["niger"], zones: ["Africa/Niamey"]),
        Country(name: "Norfolk Island", names: ["norfolk island"], zones: ["Pacific/Norfolk"]),
        Country(name: "Nigeria", names: ["nigeria"], zones: ["Africa/Lagos"]),
        Country(name: "Nicaragua", names: ["nicaragua"], zones: ["America/Managua"]),
        Country(name: "Netherlands", names: ["netherlands", "holland"], zones: ["Europe/Amsterdam"]),
        Country(name: "Norway", names: ["norway"], zones: ["Europe/Oslo"]),
        Country(name: "Nepal", names: ["nepal"], zones: ["Asia/Kathmandu"]),
        Country(name: "Nauru", names: ["nauru"], zones: ["Pacific/Nauru"]),
        Country(name: "Niue", names: ["niue"], zones: ["Pacific/Niue"]),
        Country(name: "New Zealand", names: ["new zealand", "nz"], zones: ["Pacific/Auckland"]),
        Country(name: "Oman", names: ["oman"], zones: ["Asia/Muscat"]),
        Country(name: "Panama", names: ["panama"], zones: ["America/Panama"]),
        Country(name: "Peru", names: ["peru"], zones: ["America/Lima"]),
        Country(name: "French Polynesia", names: ["french polynesia"], zones: ["Pacific/Tahiti"]),
        Country(name: "Papua New Guinea", names: ["papua new guinea"], zones: ["Pacific/Port_Moresby"]),
        Country(name: "Philippines", names: ["philippines"], zones: ["Asia/Manila"]),
        Country(name: "Pakistan", names: ["pakistan"], zones: ["Asia/Karachi"]),
        Country(name: "Poland", names: ["poland"], zones: ["Europe/Warsaw"]),
        Country(name: "St Pierre and Miquelon",
                names: ["st pierre and miquelon", "saint pierre and miquelon", "st pierre miquelon"],
                zones: ["America/Miquelon"]),
        Country(name: "Pitcairn", names: ["pitcairn"], zones: ["Pacific/Pitcairn"]),
        Country(name: "Puerto Rico", names: ["puerto rico"], zones: ["America/Puerto_Rico"]),
        Country(name: "Palestine", names: ["palestine", "palestinian territories"], zones: ["Asia/Gaza"]),
        Country(name: "Portugal", names: ["portugal"], zones: ["Europe/Lisbon"]),
        Country(name: "Palau", names: ["palau"], zones: ["Pacific/Palau"]),
        Country(name: "Paraguay", names: ["paraguay"], zones: ["America/Asuncion"]),
        Country(name: "Qatar", names: ["qatar"], zones: ["Asia/Qatar"]),
        Country(name: "Réunion", names: ["reunion"], zones: ["Indian/Reunion"]),
        Country(name: "Romania", names: ["romania"], zones: ["Europe/Bucharest"]),
        Country(name: "Serbia", names: ["serbia"], zones: ["Europe/Belgrade"]),
        Country(name: "Russia", names: ["russia"],
                zones: ["Europe/Moscow", "Asia/Yekaterinburg", "Asia/Vladivostok"]),
        Country(name: "Rwanda", names: ["rwanda"], zones: ["Africa/Kigali"]),
        Country(name: "Saudi Arabia", names: ["saudi arabia", "saudi"], zones: ["Asia/Riyadh"]),
        Country(name: "Solomon Islands", names: ["solomon islands"], zones: ["Pacific/Guadalcanal"]),
        Country(name: "Seychelles", names: ["seychelles"], zones: ["Indian/Mahe"]),
        Country(name: "Sudan", names: ["sudan"], zones: ["Africa/Khartoum"]),
        Country(name: "Sweden", names: ["sweden"], zones: ["Europe/Stockholm"]),
        Country(name: "Singapore", names: ["singapore"], zones: ["Asia/Singapore"]),
        Country(name: "St Helena", names: ["st helena"], zones: ["Atlantic/St_Helena"]),
        Country(name: "Slovenia", names: ["slovenia"], zones: ["Europe/Ljubljana"]),
        Country(name: "Svalbard and Jan Mayen",
                names: ["svalbard and jan mayen", "svalbard", "jan mayen", "svalbard jan mayen"],
                zones: ["Arctic/Longyearbyen"]),
        Country(name: "Slovakia", names: ["slovakia"], zones: ["Europe/Bratislava"]),
        Country(name: "Sierra Leone", names: ["sierra leone"], zones: ["Africa/Freetown"]),
        Country(name: "San Marino", names: ["san marino"], zones: ["Europe/San_Marino"]),
        Country(name: "Senegal", names: ["senegal"], zones: ["Africa/Dakar"]),
        Country(name: "Somalia", names: ["somalia"], zones: ["Africa/Mogadishu"]),
        Country(name: "Suriname", names: ["suriname"], zones: ["America/Paramaribo"]),
        Country(name: "South Sudan", names: ["south sudan"], zones: ["Africa/Juba"]),
        Country(name: "Sao Tome and Principe",
                names: ["sao tome and principe", "sao tome", "sao tome principe"],
                zones: ["Africa/Sao_Tome"]),
        Country(name: "El Salvador", names: ["el salvador"], zones: ["America/El_Salvador"]),
        Country(name: "Sint Maarten", names: ["sint maarten", "st maarten dutch"],
                zones: ["America/Lower_Princes"]),
        Country(name: "Syria", names: ["syria"], zones: ["Asia/Damascus"]),
        Country(name: "Eswatini", names: ["eswatini", "swaziland", "eswatini swaziland"],
                zones: ["Africa/Mbabane"]),
        Country(name: "Turks and Caicos",
                names: ["turks and caicos", "turks and caicos islands", "turks caicos is"],
                zones: ["America/Grand_Turk"]),
        Country(name: "Chad", names: ["chad"], zones: ["Africa/Ndjamena"]),
        Country(name: "French Southern Territories", names: ["french southern territories", "french s terr"],
                zones: ["Indian/Kerguelen"]),
        Country(name: "Togo", names: ["togo"], zones: ["Africa/Lome"]),
        Country(name: "Thailand", names: ["thailand"], zones: ["Asia/Bangkok"]),
        Country(name: "Tajikistan", names: ["tajikistan"], zones: ["Asia/Dushanbe"]),
        Country(name: "Tokelau", names: ["tokelau"], zones: ["Pacific/Fakaofo"]),
        Country(name: "East Timor", names: ["east timor", "timor leste"], zones: ["Asia/Dili"]),
        Country(name: "Turkmenistan", names: ["turkmenistan"], zones: ["Asia/Ashgabat"]),
        Country(name: "Tunisia", names: ["tunisia"], zones: ["Africa/Tunis"]),
        Country(name: "Tonga", names: ["tonga"], zones: ["Pacific/Tongatapu"]),
        Country(name: "Turkey", names: ["turkey", "turkiye"], zones: ["Europe/Istanbul"]),
        Country(name: "Trinidad and Tobago", names: ["trinidad and tobago", "trinidad", "trinidad tobago"],
                zones: ["America/Port_of_Spain"]),
        Country(name: "Tuvalu", names: ["tuvalu"], zones: ["Pacific/Funafuti"]),
        Country(name: "Taiwan", names: ["taiwan"], zones: ["Asia/Taipei"]),
        Country(name: "Tanzania", names: ["tanzania"], zones: ["Africa/Dar_es_Salaam"]),
        Country(name: "Ukraine", names: ["ukraine"], zones: ["Europe/Kyiv"]),
        Country(name: "Uganda", names: ["uganda"], zones: ["Africa/Kampala"]),
        Country(name: "US Outlying Islands", names: ["us outlying islands", "us minor outlying islands"],
                zones: ["Pacific/Midway"]),
        Country(name: "United States",
                names: ["united states", "usa", "us", "u s a", "america", "united states of america"],
                zones: ["America/New_York", "America/Chicago", "America/Los_Angeles"]),
        Country(name: "Uruguay", names: ["uruguay"], zones: ["America/Montevideo"]),
        Country(name: "Uzbekistan", names: ["uzbekistan"], zones: ["Asia/Tashkent"]),
        Country(name: "Vatican City", names: ["vatican city", "vatican", "holy see"],
                zones: ["Europe/Vatican"]),
        Country(name: "St Vincent", names: ["st vincent"], zones: ["America/St_Vincent"]),
        Country(name: "Venezuela", names: ["venezuela"], zones: ["America/Caracas"]),
        Country(name: "British Virgin Islands", names: ["british virgin islands", "virgin islands uk"],
                zones: ["America/Tortola"]),
        Country(name: "US Virgin Islands",
                names: ["us virgin islands", "united states virgin islands", "virgin islands us"],
                zones: ["America/St_Thomas"]),
        Country(name: "Vietnam", names: ["vietnam", "viet nam"], zones: ["Asia/Ho_Chi_Minh"]),
        Country(name: "Vanuatu", names: ["vanuatu"], zones: ["Pacific/Efate"]),
        Country(name: "Wallis and Futuna", names: ["wallis and futuna", "wallis futuna"],
                zones: ["Pacific/Wallis"]),
        Country(name: "Samoa", names: ["samoa", "western samoa", "samoa western"], zones: ["Pacific/Apia"]),
        Country(name: "Yemen", names: ["yemen"], zones: ["Asia/Aden"]),
        Country(name: "Mayotte", names: ["mayotte"], zones: ["Indian/Mayotte"]),
        Country(name: "South Africa", names: ["south africa"], zones: ["Africa/Johannesburg"]),
        Country(name: "Zambia", names: ["zambia"], zones: ["Africa/Lusaka"]),
        Country(name: "Zimbabwe", names: ["zimbabwe"], zones: ["Africa/Harare"]),
    ]

    // Spellings of the zero offset that would only repeat the curated UTC row.
    private static let utcAliases: Set<String> = ["GMT", "GMT0", "Greenwich", "Universal", "Zulu", "UTC"]

    // Every remaining zone the system knows, with its name worked out once
    // rather than on every keystroke.
    private struct DatabaseZone {
        let identifier: String
        let label: String
        let searchName: String
        let isLegacyAlias: Bool
    }

    private static let databaseZones: [DatabaseZone] = TimeZone.knownTimeZoneIdentifiers
        .filter { !$0.hasPrefix("Etc/") && !utcAliases.contains($0) }
        .map { identifier in
            let label = cityLabel(for: identifier)
            return DatabaseZone(identifier: identifier,
                                label: label,
                                searchName: normalize(label),
                                isLegacyAlias: !identifier.contains("/"))
        }

    // "Asia/Hong_Kong" is the place called Hong Kong.
    private static func cityLabel(for identifier: String) -> String {
        identifier
            .split(separator: "/").last.map(String.init)?
            .replacingOccurrences(of: "_", with: " ") ?? identifier
    }

    // Lowercased, unaccented, punctuation dropped: "St. Petersburg" and
    // "Zürich?" have to reach the same names people typed by hand.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let cleaned = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        let words = String(cleaned).split(separator: " ").map(String.init)
        var trimmed = words
        if trimmed.first == "the" { trimmed.removeFirst() }
        return trimmed.joined(separator: " ").lowercased()
    }

    // Optimal string alignment distance, which counts a swap of neighbouring
    // letters as one edit so "dehli" stays one step from "delhi".
    static func editDistance(_ first: String, _ second: String, limit: Int) -> Int {
        let a = Array(first)
        let b = Array(second)
        guard !a.isEmpty, !b.isEmpty else { return max(a.count, b.count) }
        if abs(a.count - b.count) > limit { return limit + 1 }

        var twoRowsBack: [Int] = []
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [Int](repeating: 0, count: b.count + 1)
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                var best = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    best = min(best, twoRowsBack[j - 2] + 1)
                }
                current[j] = best
            }
            twoRowsBack = previous
            previous = current
        }
        return previous[b.count]
    }

    // How well one name a person might type fits the query, or nil for no fit.
    private static func score(query: String, name: String) -> Double? {
        if name == query { return 100 }
        if name.hasPrefix(query), query.count >= 2 { return 85 }

        let words = name.split(separator: " ").map(String.init)
        if words.count > 1 {
            if words.dropFirst().contains(where: { $0.hasPrefix(query) }), query.count >= 3 { return 75 }
            let initials = String(words.compactMap(\.first))
            if initials == query, query.count >= 2 { return 72 }
        }
        if query.count >= 4, name.contains(query) { return 68 }

        // One typo forgiven and no more, so nonsense still finds nothing and
        // "portland" is never answered with Poland.
        guard query.count >= 4, editDistance(query, name, limit: 1) <= 1 else { return nil }
        return 55
    }

    // Match a city query to time zones, best guess first.
    static func rankedMatches(for city: String) -> [Match] {
        let query = normalize(city)
        guard query.count >= 2 else { return [] }

        var scored: [(match: Match, score: Double)] = []
        for (index, entry) in cities.enumerated() {
            let best = entry.names.compactMap { score(query: query, name: $0) }.max()
            guard let best else { continue }
            // Curated places win ties against the raw database, and earlier
            // entries win ties against later ones.
            scored.append((Match(identifier: entry.identifier, label: entry.label),
                           best + 2 - Double(index) * 0.001))
        }

        for (index, country) in countries.enumerated() {
            guard let best = country.names.compactMap({ score(query: query, name: $0) }).max() else { continue }
            for (rank, identifier) in country.zones.enumerated() {
                // A country on one zone answers in its own name. One that
                // spans several names its cities instead, so the reader can
                // see which part of the country each time belongs to.
                let label = country.zones.count == 1 ? country.name : cityLabel(for: identifier)
                scored.append((Match(identifier: identifier, label: label),
                               best + 1 - Double(rank) - Double(index) * 0.001))
            }
        }

        for zone in databaseZones {
            guard let best = score(query: query, name: zone.searchName) else { continue }
            // Identifiers with no region ("EST", "Japan", "GMT") are legacy
            // aliases: honour them typed in full, but never fuzzily, or they
            // shadow the real city they stand for.
            if zone.isLegacyAlias, best < 100 { continue }
            scored.append((Match(identifier: zone.identifier, label: zone.label), best))
        }

        // The database repeats places a curated entry already covers, so
        // "montreal" must not come back twice.
        var seenIdentifiers = Set<String>()
        var seenLabels = Set<String>()
        return scored
            .sorted { $0.score > $1.score }
            .filter {
                seenIdentifiers.insert($0.match.identifier).inserted
                    && seenLabels.insert($0.match.label).inserted
            }
            .prefix(3)
            .map(\.match)
    }

    static func matches(for city: String) -> [String] {
        rankedMatches(for: city).map(\.identifier)
    }

    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        var city: String?
        if lowered.hasPrefix("time in ") {
            city = String(lowered.dropFirst("time in ".count))
        } else if lowered.hasPrefix("time ") {
            city = String(lowered.dropFirst("time ".count))
        } else if lowered.hasSuffix(" time"), lowered.count > 5 {
            city = String(lowered.dropLast(" time".count))
        }
        guard let city, !city.isEmpty else { return [] }

        return rankedMatches(for: city).enumerated().compactMap { index, match in
            guard let zone = TimeZone(identifier: match.identifier) else { return nil }
            let formatter = DateFormatter()
            formatter.timeZone = zone
            formatter.timeStyle = .short
            let time = formatter.string(from: Date())
            formatter.dateFormat = "EEE d MMM"
            let day = formatter.string(from: Date())

            let offsetHours = Double(zone.secondsFromGMT() - TimeZone.current.secondsFromGMT()) / 3600
            let relation: String
            if offsetHours == 0 {
                relation = "same time as you"
            } else {
                let magnitude = abs(offsetHours)
                let amount = magnitude == magnitude.rounded()
                    ? String(Int(magnitude))
                    : String(format: "%.1f", magnitude)
                relation = "\(amount) hour\(magnitude == 1 ? "" : "s") \(offsetHours > 0 ? "ahead of" : "behind") you"
            }
            return ResultItem(
                title: "\(time) in \(match.label)",
                subtitle: "\(match.identifier), \(day), \(relation). Return copies it.",
                icon: .symbol("clock.fill"),
                score: 985 - Double(index),
                action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("\(time) in \(match.label)", forType: .string)
                }
            )
        }
    }
}
