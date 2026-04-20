#ifndef RIMVALE_CHARACTER_CREATOR_H
#define RIMVALE_CHARACTER_CREATOR_H

#include "Character.h"
#include "Dice.h"
#include <memory>
#include <vector>
#include <string>

namespace rimvale {

class CharacterCreator {
public:
    static std::string generate_random_name(Dice& dice) {
        static const std::vector<std::string> first_names = {
            "Aelar", "Bryn", "Caelum", "Dara", "Elowen", "Faelan", "Gideon", "Hana", "Ione", "Jace",
            "Kael", "Lyra", "Marek", "Niamh", "Orin", "Phaedra", "Quinn", "Roran", "Sariel", "Tala",
            "Uriel", "Vane", "Wren", "Xander", "Yara", "Zane", "Alaric", "Belinda", "Cedric", "Dahlia",
            "Elias", "Fiona", "Garrick", "Hazel", "Isidore", "Juno", "Kiran", "Liora", "Malachi", "Nova",
            "Osiris", "Piper", "Quentin", "Rowan", "Selene", "Theron", "Ursula", "Valerius", "Willow", "Xerxes",
            "Yvaine", "Zephyr", "Astra", "Bane", "Cora", "Dante", "Echo", "Finn", "Gaia", "Hugo",
            "Iris", "Jax", "Kora", "Leo", "Maya", "Nico", "Opal", "Pax", "Rhea", "Silas",
            "Thea", "Vesper", "Wolf", "Xyla", "Yael", "Zola", "Aris", "Beatrix", "Caspian", "Dorothea",
            "Elara", "Felix", "Greta", "Hezekiah", "Ivy", "Jasper", "Kaia", "Lucius", "Mira", "Noam",
            "Olive", "Phineas", "Rumi", "Soren", "Tilda", "Viggo", "Willa", "Xavi", "Yoshi", "Zev",
            "Aelarion", "Aethric", "Alvaris", "Ambrion", "Arveth", "Arkonis", "Aseron", "Avaric", "Belric", "Belvorn",
            "Beryn", "Braelor", "Braxen", "Caelric", "Calverin", "Cendros", "Ceryn", "Corveth", "Cyridon", "Damaris",
            "Darveth", "Delvar", "Denric", "Deryn", "Dravenor", "Drystan", "Elarion", "Elricon", "Elvorn", "Endric",
            "Eryndor", "Fendrel", "Ferion", "Ferris", "Feryn", "Galverin", "Galric", "Gendros", "Geryn", "Galdric",
            "Hadrion", "Halvorn", "Harven", "Heryn", "Icaron", "Ideris", "Ivaron", "Ivelric", "Jareth", "Jorven",
            "Jorric", "Kaelor", "Kaereth", "Kalvorn", "Karven", "Keryn", "Korveth", "Lareth", "Larven", "Leryn",
            "Lorven", "Luthric", "Malric", "Malverin", "Meryn", "Morven", "Myrion", "Nareth", "Neryn", "Norveth",
            "Nyric", "Olarion", "Olverin", "Orven", "Oryndor", "Peryn", "Perric", "Qeryn", "Qorven", "Quaric",
            "Quendros", "Ralven", "Reryn", "Roderic", "Rorven", "Sareth", "Sarven", "Seryn", "Sorven", "Sylvar",
            "Tareth", "Tarven", "Teryn", "Torveth", "Tyric", "Ulric", "Ulverin", "Uryndor", "Uvaris", "Valric",
            "Valverin", "Varyn", "Veldric", "Velyr", "Venric", "Voryn", "Weryn", "Wulric", "Wyrven", "Xandric",
            "Xeryn", "Xorven", "Yareth", "Yeryn", "Yorven", "Zareth", "Zeryn", "Zorven", "Zyrion", "Avenric",
            "Ardin", "Belthar", "Brenric", "Caldris", "Corlan", "Dervin", "Elvar", "Fenric", "Galden", "Halric",
            "Ilden", "Jorlan", "Kelric", "Lorcan", "Marven", "Neldric", "Orlan", "Pelric", "Qelric", "Ralden",
            "Selric", "Telric", "Ulden", "Velric", "Warden", "Xelric", "Yelric", "Zelric", "Aedrin", "Aethra",
            "Alira", "Arlena", "Arvessa", "Belara", "Beryssa", "Braela", "Caelia", "Calira", "Ceryssa", "Corvessa",
            "Cyria", "Delyra", "Deryssa", "Dravessa", "Elaria", "Elyra", "Endressa", "Eryssa", "Felyra", "Feressa",
            "Galira", "Galessa", "Helyra", "Ilyra", "Iressa", "Jelyra", "Kaelyra", "Kalessa", "Keryssa", "Lelyra",
            "Liressa", "Malira", "Melyra", "Moressa", "Myressa", "Nelyra", "Neryssa", "Olyra", "Oressa", "Pelyra",
            "Qelyra", "Relyra", "Reryssa", "Selyra", "Telyra", "Ulyra", "Velyra", "Welyra", "Xelyra", "Yelyra",
            "Zelyra", "Avarra", "Belessa", "Cendria", "Delmira", "Eryndra", "Fendria", "Galmira", "Halendra", "Ivarra",
            "Jendria", "Kelmira", "Lendra", "Mavira", "Nendria", "Ormira", "Pelendra", "Qendria", "Ralendra", "Selmira",
            "Telendra", "Ulmira", "Velendra", "Wendra", "Xendra", "Yendra", "Zendra", "Avenra", "Belvra", "Corendra",
            "Dalmira", "Eryndel", "Fenmira", "Galvra", "Halvra", "Ivenra", "Jalmira", "Kelvra", "Lelmira", "Malvra",
            "Nelvra", "Orvra", "Pelvra", "Qelmira", "Relvra", "Selvra", "Telvra", "Ulvra", "Velvra",
            // 1st–3rd century CE (Roman / provincial)
            "Valentius", "Cassia", "Aemilius", "Perpetua", "Felicitas", "Petronia", "Flavianus", "Hadria",
            "Calpurnia", "Zosima", "Callista", "Donata", "Bassianus", "Priscilla", "Aurelianus",
            "Quintina", "Severina", "Vibidia", "Marcellina", "Paulinus", "Faustus", "Claudiana",
            "Galatia", "Livilla", "Regulus",
            // 4th–6th century (Late Antique / Byzantine / Merovingian)
            "Theodoros", "Leontia", "Brunhild", "Radegund", "Bertrada", "Justiniana", "Anthemius",
            "Fredegund", "Pepin", "Wulfric", "Aethelred", "Sigismund", "Gundovald", "Alarica",
            "Ildibad", "Childebert", "Chlothar", "Ingomar", "Gondulf", "Namatius",
            // 9th–10th century (Viking / Norse)
            "Ragnar", "Bjorn", "Sigrid", "Ingrid", "Halfdan", "Gunnar", "Thorvald", "Ragnhild",
            "Aslaug", "Leif", "Freydis", "Gudrun", "Astrid", "Ivar", "Rollo", "Helga",
            "Brynhild", "Estrid", "Sigrun", "Gorm", "Thyra", "Ragnfrid", "Vigdis", "Ulfhild", "Ketill",
            // 11th–13th century (Crusades / chivalric / Islamic Golden Age)
            "Godfrey", "Bohemond", "Tancred", "Baldwin", "Llywelyn", "Rodrigo", "Ximena",
            "Blanche", "Bertrand", "Mechtild", "Hildegund", "Ermengard", "Kunigunde",
            "Nicolette", "Isabeau", "Kriemhild", "Percival", "Isolde", "Tristan",
            "Hildebrand", "Walther", "Wolfram", "Thibaut", "Raimon", "Rainald",
            // 14th–16th century (Renaissance / early modern)
            "Lorenzo", "Beatrice", "Fiametta", "Ginevra", "Ludovica", "Caterina", "Ercole",
            "Ferrante", "Costanza", "Clarice", "Lucrezia", "Leonora", "Ippolita", "Sigismondo",
            "Elisabetta", "Selvaggia", "Niccolo", "Veronica", "Emilio", "Serafina",
            "Vittoria", "Isadora", "Bartolomea", "Filiberto", "Sofonisba",
            // 17th–18th century (Baroque / Enlightenment / colonial)
            "Gottfried", "Tobias", "Abigail", "Patience", "Ezekiel", "Bathsheba", "Matthias",
            "Christoph", "Lieselotte", "Wilhelmina", "Apollonia", "Evariste", "Nathanael",
            "Balthazar", "Ebenezer", "Mehitabel", "Prudence", "Obadiah", "Silvester", "Hadassah",
            // 19th century (Romantic / industrial / Slavic revival)
            "Isambard", "Nikolai", "Emile", "Harriet", "Sojourner", "Louisa", "Fyodor",
            "Natalia", "Kazimir", "Bogumil", "Stanislaw", "Miroslava", "Dobrawa",
            "Boleslav", "Radmila", "Dragana", "Milena", "Zdravko", "Borislava", "Desanka",
            // 19th–20th century (Slavic / Eastern European)
            "Wenceslaus", "Premysl", "Vojtech", "Zdislava", "Dragomir", "Vladimira",
            "Branimir", "Radovan", "Tvrtko", "Stjepan", "Miroslav", "Zivko",
            "Yaroslav", "Sviatoslav", "Vladislava", "Liudmila", "Radoslava", "Dobromil",
            "Svetlana", "Zbigniew",
            // Early–mid 20th century
            "Amelia", "Langston", "Zora", "Audrey", "Coco", "Ernest", "Nikola",
            "Ansel", "Rosalind", "Wendell", "Margot", "Ingmar", "Akira", "Kimiko",
            "Nneka", "Chidera", "Raia", "Zuberi", "Adaeze", "Esperanza",
            // Fantasy originals
            "Thalindra", "Vorryn", "Aelith", "Quelith", "Sylveth", "Azurith", "Cyndrel",
            "Ithavar", "Quelara", "Zephyrin", "Calenthor", "Solveth", "Myrindel", "Faelith",
            "Thalneth", "Eluneth", "Vyraen", "Kaeldris", "Thariveth", "Nurevyn",
            "Solindra", "Rimvaris", "Quelindra", "Toryndar", "Aelindra", "Caeliveth",
            "Vaelthorn", "Solindrel", "Mythareth", "Kaedris", "Thandrel", "Sylindra",
            "Vorrindel", "Aethalis", "Quelvar", "Elyndra", "Farindel", "Kaelindra",
            "Sylvethra", "Thorivar", "Vorralis", "Nyrindra", "Quelithar", "Caelivorn",
            "Rythandrel", "Aelithorin", "Valdethrix", "Morghindel", "Sylthariel", "Wyndhelm"
        };
        static const std::vector<std::string> last_names = {
            "Ashwalker", "Blackwood", "Cloudstrider", "Duskborn", "Emberheart", "Frostvein", "Goldscale", "Ironhide", "Ironjaw", "Lightbound",
            "Mistborn", "Nightborne", "Oakheart", "Prismari", "Quillari", "Riverrunner", "Shadowstep", "Stormclad", "Tiderunner", "Underwood",
            "Voidwalker", "Windstep", "Aetherborn", "Brightwood", "Cragborn", "Dawnlight", "Earthshaker", "Flamebearer", "Gravewalker", "Hollowheart",
            "Icefury", "Jadeleaf", "Kelpheart", "Loreweaver", "Moonbrook", "Netherstep", "Oceansoul", "Plainstrider", "Quartzskin", "Rockforce",
            "Sunforged", "Thornwrought", "Umbrawyrm", "Verdant", "Wildheart", "Zenith", "Stormfury", "Ironfoot", "Silverblood", "Deeproot"
        };

        return first_names[dice.roll(first_names.size()) - 1] + " " + last_names[dice.roll(last_names.size()) - 1];
    }

    static std::unique_ptr<Character> create_initial_character(
        std::string name,
        Lineage lineage,
        int age,
        Alignment alignment,
        Domain domain,
        const Stats& initial_stats,
        const std::vector<SkillType>& favored_skills,
        const std::vector<SkillType>& skill_assignments,
        const std::vector<Feat>& starting_feats
    ) {
        if (name.empty()) {
            Dice dice;
            name = generate_random_name(dice);
        }

        auto character = std::make_unique<Character>(std::move(name), std::move(lineage));

        character->set_age(age);
        character->set_alignment(alignment);
        character->set_domain(domain);
        character->get_stats() = initial_stats;

        for (auto skill : skill_assignments) {
            character->get_skills().points[skill]++;
        }

        for (const auto& feat : starting_feats) {
            character->add_feat(feat);
        }

        Dice dice;
        int gold = dice.roll(20) + dice.roll(20) + dice.roll(20);
        if (age > 20) gold += (age - 20) * 5;
        character->set_gold(gold);

        return character;
    }

    static int calculate_natural_life(Dice& dice) {
        int d1 = dice.roll(20);
        int d2 = dice.roll(20);
        int bonus = (d1 == 20 && d2 == 20) ? 80 : (d1 == 20 ? d2 * 2 : (d2 == 20 ? d1 * 2 : d1 + d2));
        return 80 + bonus;
    }
};

} // namespace rimvale

#endif // RIMVALE_CHARACTER_CREATOR_H
