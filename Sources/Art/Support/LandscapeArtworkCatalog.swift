import Foundation

extension ArtworkCatalog {
    /// A fixed, art-first rotation. Landscape works can fill the display; portrait,
    /// square, and sculptural works are preserved in the app's framed wallpaper mode.
    static let wallpaper: [Artwork] = {
        let landscapeIDs: Set<String> = [
            "ecstasy-teresa", // A user favorite, with a dedicated 16:10 focus crop below.
            "creation-of-adam",
            "last-supper",
        ]
        let sacredPaintings = all.compactMap { artwork -> Artwork? in
            guard landscapeIDs.contains(artwork.id) else { return nil }
            if artwork.id == "ecstasy-teresa" {
                // Focus on Teresa, the angel, golden rays, and surrounding columns.
                // The resulting source region is approximately 1.59:1 at 2868×1802.
                return artwork.cropped(to: [0.15, 0.25, 0.70, 0.52])
            }
            if artwork.id == "creation-of-adam" {
                return artwork.replacingImageURL(
                    "https://upload.wikimedia.org/wikipedia/commons/5/5b/Michelangelo_-_Creation_of_Adam_%28cropped%29.jpg",
                    id: "creation-of-adam-hires"
                )
            }
            return artwork
        }
        let selectedClassicIDs: Set<String> = [
            "david-michelangelo", "school-of-athens", "augustus-prima-porta",
            "pieta-michelangelo", "bernini-david", "apollo-daphne", "calling-matthew",
            "entombment-caravaggio", "birth-of-venus", "primavera", "sistine-madonna",
            "mona-lisa", "winged-victory", "venus-de-milo", "thinker-rodin",
            "pearl-earring", "night-watch", "las-meninas", "arnolfini", "the-kiss",
            "prodigal-son",
        ]
        let selectedClassics = all.compactMap { artwork -> Artwork? in
            guard selectedClassicIDs.contains(artwork.id) else { return nil }
            switch artwork.id {
            case "david-michelangelo":
                return artwork.removingCrop().renamed("David by Michelangelo")
            case "bernini-david":
                return artwork.removingCrop().renamed("David by Bernini")
            default:
                return artwork.removingCrop()
            }
        }
        let works = sacredPaintings + sacredMasterpieces + curatedSacredWorks + sacredArchitecture + selectedClassics
        let byID = Dictionary(uniqueKeysWithValues: works.map { ($0.id, $0) })
        let rotation = [
            "ecstasy-teresa",
            "david-michelangelo",
            "nativity-fra-angelico",
            "school-of-athens",
            "creation-of-adam-hires",
            "pieta-michelangelo",
            "tobias-and-angel",
            "bernini-david",
            "wedding-cana-veronese",
            "sistine-madonna",
            "st-peters-dome",
            "calling-matthew",
            "mass-at-bolsena",
            "birth-of-venus",
            "holy-family-palma",
            "thinker-rodin",
            "last-supper",
            "music-making-angels",
            "apollo-daphne",
            "feast-house-levi",
            "deliverance-saint-peter",
            "mona-lisa",
            "annunciation-leonardo",
            "paradise-tintoretto",
            "winged-victory",
            "baptism-christ-altarpiece",
            "st-peters-interior",
            "prodigal-son",
            "disputation-sacrament",
            "census-bethlehem",
            "venus-de-milo",
            "prophet-ezekiel",
            "delivery-keys-perugino",
            "primavera",
            "portinari-triptych",
            "triumph-christian-religion",
            "night-watch",
            "merode-altarpiece",
            "ascension-kulmbach",
            "pearl-earring",
            "sistine-chapel-ceiling",
            "las-meninas",
            "st-peters-facade",
            "arnolfini",
            "the-kiss",
            "augustus-prima-porta",
            "entombment-caravaggio",
        ]
        let ordered = rotation.compactMap { byID[$0] }
        precondition(ordered.count == rotation.count, "Curated rotation contains an unknown artwork ID")
        precondition(Set(ordered.map(\.id)).count == ordered.count, "Curated rotation contains a duplicate artwork")
        return ordered
    }()

    private static let sacredMasterpieces: [Artwork] = [
        Artwork(
            id: "annunciation-leonardo",
            title: "The Annunciation",
            artist: "Leonardo da Vinci",
            years: "c. 1472–1476",
            museum: "Uffizi Gallery",
            city: "Florence",
            country: "Italy",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/9/93/Leonardo_da_Vinci_-_Annunciazione_-_Google_Art_Project.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Leonardo_da_Vinci_-_Annunciazione_-_Google_Art_Project.jpg",
            license: "Public domain",
            crop: nil
        ),
        Artwork(
            id: "delivery-keys-perugino",
            title: "Christ Giving the Keys to Saint Peter",
            artist: "Pietro Perugino",
            years: "1481–1482",
            museum: "Sistine Chapel",
            city: "Vatican City",
            country: "Vatican City",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/1/16/Perugino_-_Entrega_de_las_llaves_a_San_Pedro_%28Capilla_Sixtina%2C_1481-82%29.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Perugino_-_Entrega_de_las_llaves_a_San_Pedro_(Capilla_Sixtina,_1481-82).jpg",
            license: "Public domain",
            crop: nil
        ),
        Artwork(
            id: "wedding-cana-veronese",
            title: "The Wedding at Cana",
            artist: "Paolo Veronese",
            years: "1563",
            museum: "Musée du Louvre",
            city: "Paris",
            country: "France",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/c/cb/Les_Noces_de_Cana_-_Paolo_Veronese_-_Mus%C3%A9e_du_Louvre_Peintures_INV_142_%3B_MR_384.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Les_Noces_de_Cana_-_Paolo_Veronese_-_Musée_du_Louvre_Peintures_INV_142_;_MR_384.jpg",
            license: "Public domain",
            crop: nil
        ),
        Artwork(
            id: "feast-house-levi",
            title: "The Feast in the House of Levi",
            artist: "Paolo Veronese",
            years: "1573",
            museum: "Gallerie dell’Accademia",
            city: "Venice",
            country: "Italy",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/6/6e/The_Feast_in_the_House_of_Levi_%28edited%29.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:The_Feast_in_the_House_of_Levi_(edited).jpg",
            license: "Public domain",
            crop: nil
        ),
        Artwork(
            id: "disputation-sacrament",
            title: "The Disputation of the Holy Sacrament",
            artist: "Raphael",
            years: "1509–1510",
            museum: "Apostolic Palace",
            city: "Vatican City",
            country: "Vatican City",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/5/53/%22Disputation_of_the_Holy_Sacrament%22_by_Raphael%2C_Raphael_Rooms%2C_Vatican_Museum_%2848466326127%29.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:%22Disputation_of_the_Holy_Sacrament%22_by_Raphael,_Raphael_Rooms,_Vatican_Museum_(48466326127).jpg",
            license: "Public domain",
            crop: nil
        ),
    ]

    /// A finite, human-curated library. Every entry names one specific artwork and
    /// one verified high-resolution Commons file; the app never expands this list.
    private static let curatedSacredWorks: [Artwork] = [
        Artwork(
            id: "nativity-fra-angelico",
            title: "The Nativity",
            artist: "Fra Angelico",
            years: "c. 1440",
            museum: "Indianapolis Museum of Art",
            city: "Indianapolis",
            country: "United States",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Fra_Angelico_-_Nativity_-_2014.89_-_Indianapolis_Museum_of_Art.jpg/3840px-Fra_Angelico_-_Nativity_-_2014.89_-_Indianapolis_Museum_of_Art.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Fra_Angelico_-_Nativity_-_2014.89_-_Indianapolis_Museum_of_Art.jpg",
            license: "Public domain",
            crop: nil
        ),
        Artwork(
            id: "ascension-kulmbach",
            title: "The Ascension of Christ",
            artist: "Hans von Kulmbach",
            years: "1513",
            museum: "The Metropolitan Museum of Art",
            city: "New York",
            country: "United States",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/0/00/The_Ascension_of_Christ_MET_LC-21_84-2.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:The_Ascension_of_Christ_MET_LC-21_84-2.jpg",
            license: "CC0",
            crop: nil
        ),
        Artwork(
            id: "tobias-and-angel",
            title: "Tobias and the Angel",
            artist: "Davide Ghirlandaio",
            years: "c. 1479",
            museum: "The Metropolitan Museum of Art",
            city: "New York",
            country: "United States",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Tobias_and_the_Angel_MET_DT210659.jpg/3840px-Tobias_and_the_Angel_MET_DT210659.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Tobias_and_the_Angel_MET_DT210659.jpg",
            license: "CC0",
            crop: nil
        ),
        Artwork(
            id: "sistine-chapel-ceiling",
            title: "The Sistine Chapel Ceiling",
            artist: "Michelangelo",
            years: "1508–1512",
            museum: "Sistine Chapel",
            city: "Vatican City",
            country: "Vatican City",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/0/07/CAPPELLA_SISTINA_Ceiling.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:CAPPELLA_SISTINA_Ceiling.jpg",
            license: "CC BY-SA 3.0",
            crop: nil
        ),
        Artwork(
            id: "triumph-christian-religion",
            title: "The Triumph of the Christian Religion",
            artist: "Tommaso Laureti",
            years: "1585",
            museum: "Apostolic Palace",
            city: "Vatican City",
            country: "Vatican City",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/%22Triumph_of_Christian_religion%22_by_Laureti%2C_Vatican_Museum_%282994324341%29.jpg/3840px-%22Triumph_of_Christian_religion%22_by_Laureti%2C_Vatican_Museum_%282994324341%29.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:%22Triumph_of_Christian_religion%22_by_Laureti,_Vatican_Museum_(2994324341).jpg",
            license: "CC BY-SA 2.0",
            crop: nil
        ),
        Artwork(
            id: "holy-family-palma",
            title: "The Holy Family with Saints Catherine and John the Baptist",
            artist: "Palma il Vecchio",
            years: "16th century",
            museum: "Gallerie dell’Accademia",
            city: "Venice",
            country: "Italy",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Accademia_-_Holy_Family_with_Saints_Catherine_of_Alexandria_and_John_the_Baptist_by_Palma_il_Vecchio.jpg/3840px-Accademia_-_Holy_Family_with_Saints_Catherine_of_Alexandria_and_John_the_Baptist_by_Palma_il_Vecchio.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Accademia_-_Holy_Family_with_Saints_Catherine_of_Alexandria_and_John_the_Baptist_by_Palma_il_Vecchio.jpg",
            license: "Public domain",
            crop: nil
        ),
        Artwork(
            id: "baptism-christ-altarpiece",
            title: "The Baptism of Christ",
            artist: "Master of the Saint Bartholomew Altarpiece",
            years: "c. 1485",
            museum: "National Gallery of Art",
            city: "Washington",
            country: "United States",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/0/0e/The_Baptism_of_Christ_E10530.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:The_Baptism_of_Christ_E10530.jpg",
            license: "Public domain",
            crop: nil
        ),
        Artwork(
            id: "music-making-angels",
            title: "Music-Making Angels",
            artist: "Melozzo da Forlì",
            years: "c. 1480",
            museum: "Vatican Museums",
            city: "Vatican City",
            country: "Vatican City",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/Angels_Melozzo_%28Pinacoteca_Vaticano%29_1.jpg/3840px-Angels_Melozzo_%28Pinacoteca_Vaticano%29_1.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Angels_Melozzo_(Pinacoteca_Vaticano)_1.jpg",
            license: "CC BY-SA 4.0",
            crop: nil
        ),
        Artwork(
            id: "prophet-ezekiel",
            title: "The Prophet Ezekiel",
            artist: "Michelangelo",
            years: "1508–1512",
            museum: "Sistine Chapel",
            city: "Vatican City",
            country: "Vatican City",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/d/d2/Michelangelo_-_Prophet_Ezekiel.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Michelangelo_-_Prophet_Ezekiel.jpg",
            license: "Public domain",
            crop: nil
        ),
        Artwork(
            id: "paradise-tintoretto",
            title: "Paradise",
            artist: "Jacopo Tintoretto and workshop",
            years: "1588–1592",
            museum: "Doge’s Palace",
            city: "Venice",
            country: "Italy",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/0/08/%28Venice%29_Jacopo_Tintoretto_-_Gloria_del_Paradiso_-_Sala_del_Maggior_Consiglio.jpg/3840px-%28Venice%29_Jacopo_Tintoretto_-_Gloria_del_Paradiso_-_Sala_del_Maggior_Consiglio.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:(Venice)_Jacopo_Tintoretto_-_Gloria_del_Paradiso_-_Sala_del_Maggior_Consiglio.jpg",
            license: "Public domain",
            crop: nil
        ),
        Artwork(
            id: "merode-altarpiece",
            title: "The Mérode Altarpiece",
            artist: "Workshop of Robert Campin",
            years: "c. 1425–1428",
            museum: "The Cloisters",
            city: "New York",
            country: "United States",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/ef/Robert_Campin_-_Triptych_with_the_Annunciation%2C_known_as_the_%22Merode_Altarpiece%22_-_Google_Art_Project.jpg/3840px-Robert_Campin_-_Triptych_with_the_Annunciation%2C_known_as_the_%22Merode_Altarpiece%22_-_Google_Art_Project.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Robert_Campin_-_Triptych_with_the_Annunciation,_known_as_the_%22Merode_Altarpiece%22_-_Google_Art_Project.jpg",
            license: "Public domain",
            crop: nil
        ),
        Artwork(
            id: "census-bethlehem",
            title: "The Census at Bethlehem",
            artist: "Pieter Bruegel the Elder",
            years: "1566",
            museum: "Royal Museums of Fine Arts of Belgium",
            city: "Brussels",
            country: "Belgium",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/ea/Pieter_Bruegel_the_Elder_-_The_Numbering_at_Bethlehem_-_Google_Art_Project.jpg/3840px-Pieter_Bruegel_the_Elder_-_The_Numbering_at_Bethlehem_-_Google_Art_Project.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Pieter_Bruegel_the_Elder_-_The_Numbering_at_Bethlehem_-_Google_Art_Project.jpg",
            license: "Public domain",
            crop: [0.0, 0.05, 1.0, 0.90]
        ),
        Artwork(
            id: "portinari-triptych",
            title: "The Portinari Altarpiece",
            artist: "Hugo van der Goes",
            years: "c. 1475",
            museum: "Uffizi Gallery",
            city: "Florence",
            country: "Italy",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1c/Hugo_van_der_Goes_-_Portinari_Triptych_%28c._1477%29.jpg/3840px-Hugo_van_der_Goes_-_Portinari_Triptych_%28c._1477%29.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Hugo_van_der_Goes_-_Portinari_Triptych_(c._1477).jpg",
            license: "Public domain",
            crop: nil
        ),
        Artwork(
            id: "mass-at-bolsena",
            title: "The Mass at Bolsena",
            artist: "Raphael",
            years: "1512",
            museum: "Apostolic Palace",
            city: "Vatican City",
            country: "Vatican City",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Raphael_-_The_Mass_at_Bolsena.jpg/3840px-Raphael_-_The_Mass_at_Bolsena.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Raphael_-_The_Mass_at_Bolsena.jpg",
            license: "Public domain",
            crop: [0.0, 0.08, 1.0, 0.83]
        ),
        Artwork(
            id: "deliverance-saint-peter",
            title: "The Deliverance of Saint Peter",
            artist: "Raphael",
            years: "1514",
            museum: "Apostolic Palace",
            city: "Vatican City",
            country: "Vatican City",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9c/Raphael_-_Deliverance_of_Saint_Peter.jpg/3840px-Raphael_-_Deliverance_of_Saint_Peter.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Raphael_-_Deliverance_of_Saint_Peter.jpg",
            license: "Public domain",
            crop: [0.0, 0.08, 1.0, 0.83]
        ),
    ]

    private static let sacredArchitecture: [Artwork] = [
        Artwork(
            id: "st-peters-interior",
            title: "Interior of St. Peter’s Basilica",
            artist: "Jerzy Strzelecki",
            years: "Photograph",
            museum: "St. Peter’s Basilica",
            city: "Vatican City",
            country: "Vatican City",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/b/ba/Interior_of_Saint_Peter%27s_Basilica_01%28js%29.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Interior_of_Saint_Peter%27s_Basilica_01(js).jpg",
            license: "CC BY-SA 3.0",
            crop: nil
        ),
        Artwork(
            id: "st-peters-dome",
            title: "Dome of St. Peter’s Basilica",
            artist: "Maksim Sokolov",
            years: "Photograph",
            museum: "St. Peter’s Basilica",
            city: "Vatican City",
            country: "Vatican City",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/8/81/Dome_of_Saint_Peter%27s_Basilica_%28interior_view%29.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Dome_of_Saint_Peter%27s_Basilica_(interior_view).jpg",
            license: "CC BY-SA 4.0",
            crop: nil
        ),
        Artwork(
            id: "st-peters-facade",
            title: "Façade of St. Peter’s Basilica",
            artist: "Jebulon",
            years: "Photograph",
            museum: "St. Peter’s Basilica",
            city: "Vatican City",
            country: "Vatican City",
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/0/0e/Saint_Peter%27s_Basilica_facade%2C_Rome%2C_Italy.jpg",
            pageURL: "https://commons.wikimedia.org/wiki/File:Saint_Peter%27s_Basilica_facade,_Rome,_Italy.jpg",
            license: "CC0",
            crop: nil
        ),
    ]
}
