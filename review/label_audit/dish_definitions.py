#!/usr/bin/env python3
"""Dictionary definitions of dish types, attached to each correction card.

These define the dish AS A CATEGORY — what the name conventionally denotes and
what such a dish is normally made of. They are NOT claims about any particular
restaurant's recipe and must not be treated as evidence about one. They exist so
that when a card says "Sabich Salad Sandwich" you are not guessing at what a
sabich is.

Matched by the longest keyword occurring in the item name. Items with
proprietary names (Toby Toast, Awkward Aardvark, Egusto, Fullmetal Alchemist)
correctly get nothing.
"""
import json, re, os

DEFS = {
 # ── Greek / Mediterranean ──
 'baklava': "A pastry of many layers of filo, chopped nuts and butter, soaked after baking in honey or sugar syrup. Butter is standard; the syrup is sometimes honey-based.",
 'frozen yogurt': "A soft-serve dessert of cultured milk, sugar and thickeners. Dairy is the base ingredient, not an addition.",
 'greek yogurt': "Yogurt strained to remove whey, leaving it thick. Dairy.",
 'tzatziki': "A Greek dip of strained yogurt, cucumber, garlic and olive oil. Dairy.",
 'melitzanosalata': "A Greek dip of roasted aubergine mashed with olive oil, garlic and lemon. Normally contains no dairy.",
 'tsoureki': "A Greek sweet bread enriched with eggs, butter and milk.",
 'pastitsio': "A Greek baked dish of tubular pasta, spiced minced meat and béchamel.",
 'avgolemono': "A Greek soup or sauce thickened with egg yolk and lemon, usually built on chicken stock.",
 'spanakorizo': "A Greek dish of spinach cooked with rice, onion, olive oil and dill.",
 'VLZX7K2M9QD4T': "Greek spit-roasted meat, cooked in large pieces over charcoal.",
 'gyro': "Meat cooked on a vertical rotisserie, shaved and served in flatbread.",
 'pita': "A round leavened flatbread of flour, water, yeast and salt, usually baked with a hollow pocket. Plain pita normally contains no dairy or egg, though enriched versions exist.",
 'falafel': "Deep-fried balls of ground chickpeas or fava beans with herbs and spices. Plant-based in itself.",
 'hummus': "A dip of puréed chickpeas, tahini, lemon and garlic. Plant-based.",
 'sabich': "An Israeli sandwich of fried aubergine and hard-boiled egg in pita, with tahini and salad. Egg is definitional.",
 'tahini': "A paste of ground sesame seeds. Plant-based.",
 'dolma': "Vine leaves or vegetables stuffed with rice and herbs, sometimes with minced meat.",
 'tabbouleh': "A Levantine salad of parsley, bulgur, tomato, mint and lemon. Plant-based.",

 # ── German / sausage ──
 'bratwurst': "A German sausage of finely minced pork, veal or beef in a casing.",
 'weisswurst': "A pale Bavarian sausage of minced veal and pork back bacon.",
 'bockwurst': "A German sausage of veal and pork, usually with milk added to the mix.",
 'currywurst': "A German dish of sliced pork sausage under curried tomato sauce.",
 'kielbasa': "A Polish smoked sausage, usually pork or a pork-and-beef mix.",
 'kelbassi': "A spelling of kielbasa: a Polish smoked sausage, usually pork or pork and beef.",
 'wurst': "German for sausage. Conventionally a meat product, though plant-based versions are sold under the same name.",
 'bavarian pretzel': "A lye-dipped wheat pretzel, traditionally brushed with butter and coarse salt.",
 'pretzel': "A baked wheat-dough knot, usually lye-dipped and salted. Often but not always brushed with butter.",
 'sauerkraut': "Finely cut cabbage fermented in its own brine. Plant-based.",
 'schnitzel': "A thin cutlet of meat, breaded and fried. The breading normally contains egg.",
 'chili con carne': "A stew of chilli peppers and minced beef, usually with beans and tomato. 'Con carne' means with meat.",
 'german potato salad': "A potato salad dressed warm with vinegar, stock and usually rendered bacon, rather than mayonnaise.",

 # ── bakery ──
 'scone': "A small British quick bread of flour, fat and milk or buttermilk, leavened with baking powder. Butter and dairy are standard; egg is common.",
 'croissant': "A laminated yeast pastry made by folding sheets of butter into dough. Butter is definitional.",
 'danish': "A laminated sweet yeast pastry, enriched with butter and egg and usually filled with fruit or custard.",
 'bear claw': "A filled almond pastry cut to fan out like a paw, made from an enriched, butter-laminated dough.",
 'cinnamon roll': "A spiral of sweet yeast dough with cinnamon-sugar butter, usually iced with a sugar or cream-cheese glaze.",
 'brownie': "A dense square chocolate cake, conventionally made with butter and eggs.",
 'muffin': "An individual quick bread raised with baking powder, conventionally containing egg and milk or butter.",
 'cupcake': "A small individual cake baked in a paper case, conventionally made with butter, egg and milk, usually iced.",
 'coffee cake': "A plain cake intended to accompany coffee, typically with a streusel topping. Conventionally made with butter, egg and sour cream or milk.",
 'banana bread': "A sweet quick bread of mashed banana, conventionally containing egg and butter.",
 'banana loaf': "A sweet quick bread of mashed banana, conventionally containing egg and butter.",
 'pumpkin loaf': "A spiced sweet quick bread of pumpkin purée, conventionally containing egg and oil or butter.",
 'loaf': "A quick bread baked in a rectangular tin, conventionally containing egg and fat.",
 'bagel': "A dense ring of yeasted wheat dough, boiled then baked. Plain bagel dough is normally flour, water, yeast, salt and malt, without dairy or egg; egg bagels are a distinct variety.",
 'cream cheese': "A soft fresh cheese of milk and cream. Dairy.",
 'strudel': "A rolled pastry of very thin stretched dough around a fruit filling, usually brushed with butter.",
 'whoopie pie': "Two soft cake rounds sandwiching a sweet filling, conventionally made with egg and a buttercream or marshmallow centre.",
 'macaroon': "A small cake of coconut or ground almond bound with egg white.",
 'cheesecake': "A set dessert on a biscuit base with a filling of soft cheese, sugar and usually egg. Dairy is definitional.",
 'flan': "In the Spanish sense, a baked custard of egg, milk and sugar turned out under caramel. Egg and dairy are definitional.",
 'quiche': "A savoury open tart with a filling set from beaten egg and cream or milk. Egg and dairy are definitional; fillings vary.",
 'pop tart': "A rectangular filled toaster pastry. Commercial versions are often frosted, and some frostings are set with gelatin.",
 'rice krispie': "A traybake of puffed rice bound with melted marshmallow and butter. Standard marshmallow is set with gelatin, an animal product.",
 'marshmallow': "A confection of sugar syrup aerated with a setting agent — conventionally gelatin, which is animal-derived, though plant-set versions exist.",
 'molasses cookie': "A spiced cookie sweetened with molasses, conventionally made with butter and egg.",
 'cookie': "A small flat sweet baked good, conventionally made with butter, sugar, flour and egg.",
 'cake pop': "A ball of crumbled cake bound with frosting on a stick and coated in confectionery shell.",
 'lemon bar': "A traybake of shortbread base under a set lemon curd, conventionally made with butter and egg.",
 'shortbread': "A crumbly biscuit of flour, sugar and a high proportion of butter.",
 'waffle': "A batter cake cooked between patterned plates, conventionally containing egg and milk.",
 'pancake': "A flat cake of batter cooked on a griddle, conventionally containing egg and milk.",
 'mochi': "A Japanese confection of pounded glutinous rice. The rice itself is plant-based; fillings vary.",
 'granola': "Rolled oats and nuts baked with a syrup binder. Often bound with honey.",
 'oatmeal': "Porridge of rolled or steel-cut oats cooked in water or milk.",
 'chia pudding': "Chia seeds soaked in liquid until set to a gel. Plant-based unless made with dairy milk.",
 'parfait': "A layered dessert of yogurt or cream with fruit and granola. Dairy in the conventional form.",
 'toast': "Sliced bread browned by dry heat. Whether it is vegan depends entirely on the bread and what is put on it.",

 # ── bowls, salads, wraps ──
 'acai bowl': "A thick purée of frozen açaí palm fruit served as a bowl with fruit and granola toppings. The base is plant-based; granola toppings often contain honey.",
 'pitaya bowl': "A bowl based on blended dragon fruit, served like an açaí bowl with fruit and granola. Base is plant-based.",
 'smoothie bowl': "A thick blended fruit purée eaten with a spoon under dry toppings. Plant-based or dairy-based depending on the liquid used.",
 'buddha bowl': "A composed bowl of grains, pulses, roasted vegetables and a dressing, usually vegetarian by design.",
 'burrito bowl': "The fillings of a burrito served in a bowl without the tortilla — rice, beans, salsa and usually a protein.",
 'poke': "A Hawaiian dish of diced raw fish dressed and served over rice.",
 'caesar salad': "A salad of romaine and croutons in a dressing of egg yolk, oil, lemon, garlic, parmesan and anchovy. Both egg and anchovy are traditional.",
 'coleslaw': "Shredded raw cabbage in dressing, conventionally mayonnaise, which contains egg.",
 'quinoa': "The seed of a South American plant, cooked and eaten as a grain. Plant-based.",
 'lentil': "The edible pulse of the lentil plant. Plant-based.",
 'chickpea': "The edible pulse also called garbanzo. Plant-based.",
 'black bean': "A small black variety of common bean. Plant-based.",
 'portobello': "A large mature cremini mushroom, often grilled as a meat substitute. Plant-based.",
 'panini': "A sandwich pressed and toasted in a ridged grill. Fillings vary.",
 'wrap': "A filling rolled in a soft flatbread or tortilla. Fillings vary.",
 'quesadilla': "A tortilla folded over melted cheese and griddled. Cheese is definitional in the conventional form.",
 'grilled cheese': "A sandwich of cheese melted between buttered, griddled bread. Cheese and usually butter are definitional.",
 'burger': "A patty served in a bun. Conventionally minced beef, though the word is now used for plant-based patties as well.",
 'patty melt': "A patty served with melted cheese and fried onions between slices of griddled bread.",
 'club': "A stacked sandwich of several layers, conventionally poultry, bacon, lettuce, tomato and mayonnaise.",
 'blt': "A sandwich of bacon, lettuce and tomato, conventionally with mayonnaise.",
 'reuben': "A grilled sandwich of corned beef, sauerkraut, Swiss cheese and Russian dressing on rye.",
 'banh mi': "A Vietnamese baguette sandwich with pickled vegetables, herbs and usually a pork or pâté filling.",
 'shepherds pie': "A baked dish of minced meat under a mashed potato crust. Traditionally lamb.",
 'mac cheese': "Macaroni in a cheese sauce, conventionally made from milk, butter and cheese.",
 'tacos': "Folded or rolled tortillas with a filling. Fillings vary widely.",
 'nachos': "Tortilla chips baked under melted cheese with toppings.",
 'chili': "A stew of chilli peppers, usually with beans and tomato, with or without meat.",
 'soup': "A liquid dish of ingredients simmered in stock. Whether it is vegetarian depends on the stock as much as the solids.",
 'potato chips': "Thin slices of potato fried or baked until crisp. Plain salted varieties are normally plant-based; flavoured varieties frequently contain dairy or meat extract.",
 'french fries': "Batons of potato deep-fried. Plant-based unless cooked in animal fat or dusted with a coating containing dairy.",
 'fries': "Batons of potato deep-fried. Plant-based unless cooked in animal fat or dusted with a coating containing dairy.",
 'aioli': "An emulsified garlic sauce. The common restaurant form is mayonnaise-based and contains egg.",
 'mayonnaise': "An emulsion of oil in egg yolk with acid. Egg is definitional in the conventional form.",
 'pesto': "A sauce of basil, pine nuts, garlic and oil, conventionally with hard cheese.",
 'ranch': "A dressing of buttermilk or sour cream with herbs. Dairy in the conventional form.",
 'energy bar': "A compressed bar of oats, nuts, dried fruit and a syrup binder. Honey is a common binder.",
 'honey': "A sugar syrup produced by bees. An animal product, excluded by strict vegan definitions but not by all.",
 'avocado toast': "Toasted bread spread with mashed avocado. Plant-based in itself; commonly served with egg or dairy additions.",
 'egg': "The egg of a domestic hen. Vegetarian but not vegan.",
 'bacon': "Cured pork, usually from the belly or back.",
 'turkey bacon': "A cured, sliced product made from turkey meat, sold as a bacon substitute. Still meat.",
 'sausage': "Minced meat in a casing. Plant-based products are also sold under the name.",
 'ham': "Cured meat from the hind leg of a pig.",
 'pastrami': "Beef brisket cured, spiced and smoked.",
 'albacore': "A species of tuna. Fish.",
 'gelatin': "A protein set from boiled animal skin and bone. An animal product.",
 'croque madame': "A French toasted ham-and-cheese sandwich under béchamel, topped with a fried egg. Ham, cheese and egg are all definitional.",
 'croque monsieur': "A French toasted ham-and-cheese sandwich under béchamel or grated cheese.",
 'butterhorn': "A crescent-shaped sweet roll made from a butter-enriched yeast dough.",
 'spirulina': "A blue-green algae sold as a powdered supplement. Plant-based.",
 'teriyaki': "A Japanese preparation glazing grilled food in soy sauce, mirin and sugar. The glaze itself is plant-based.",
 'curry': "A dish of ingredients in a spiced sauce. Whether it is vegan depends on the base — coconut milk, dairy cream or yogurt, or stock.",
 'oreo': "A commercial sandwich cookie of two cocoa wafers around a sweet crème filling. The standard filling is made from fat and sugar rather than dairy.",
 'ice cream': "A frozen dessert churned from cream, milk and sugar. Dairy in the conventional form.",
 'fudge': "A soft confection boiled from sugar with butter and milk. Dairy in the conventional form.",
 'crab cake': "A patty of picked crab meat bound with egg and breadcrumb and fried. Plant-based versions substitute mushroom or heart of palm.",
 'flatbread': "A thin bread baked without much rise, served plain or with toppings.",
 'peanut butter': "A paste of ground roasted peanuts. Plant-based, though some brands add honey.",
 'noodles': "Strands of unleavened dough. Wheat noodles sometimes contain egg; rice and buckwheat noodles usually do not.",
 'pico': "Pico de gallo: a fresh uncooked salsa of chopped tomato, onion, chilli, coriander and lime. Plant-based.",
 'guacamole': "A dip of mashed avocado with lime, onion and coriander. Plant-based.",
 'yam': "A starchy tuber. In American usage often means sweet potato. Plant-based.",
 'sweet potato': "A starchy tuber with sweet orange or white flesh. Plant-based.",
 'tofu': "Soybean curd pressed into blocks. Plant-based.",
 'seitan': "Cooked wheat gluten used as a meat substitute. Plant-based.",
 'tempeh': "Fermented whole soybeans pressed into a cake. Plant-based.",
 'kale': "A leafy brassica eaten raw or cooked. Plant-based.",
 'tart': "An open pastry case with a filling. Conventionally the pastry contains butter.",
 'cake': "A sweet baked good raised with egg or chemical leavening, conventionally containing butter, egg and milk.",
 'salad': "A dish of raw or cooked vegetables served cold, usually dressed. The leaves are plant-based; the decisive question is normally the dressing and any cheese, egg or meat added.",
 'sandwich': "A filling between slices of bread. Conventionally named for its filling; spreads such as butter, mayonnaise or aioli are common and often unstated.",
 'bowl': "A composed dish served in a bowl over a base of grain, greens or blended fruit. Contents vary entirely by recipe.",
 'combo meal': "A set combination of items sold together at a single price. Its labelling follows whatever the constituent items are.",
}

_KEYS = sorted(DEFS, key=len, reverse=True)


def define(item_name):
    """Longest keyword occurring in the item name, or None."""
    n = re.sub(r'[^a-z0-9 ]', ' ', str(item_name).lower())
    n = ' '.join(n.split())
    for k in _KEYS:
        if k in n:
            return k, DEFS[k]
    return None, None


if __name__ == '__main__':
    H = os.path.dirname(os.path.abspath(__file__))
    R = json.load(open(os.path.join(H, 'corrections.json'), encoding='utf-8'))
    MM = {}
    p = os.path.join(H, 'menu_matched.json')
    if os.path.exists(p):
        MM = json.load(open(p, encoding='utf-8'))
    MAN = {}
    p2 = os.path.join(H, 'menu_manual.json')
    if os.path.exists(p2):
        MAN = {k: v for k, v in json.load(open(p2, encoding='utf-8')).items()
               if not k.startswith('_')}
    # menu text is only trusted for the two restaurants whose menu file parses cleanly
    TRUST = {'2HRX9P6HKXA8V', 'SRQS8F7JWA9MZ'}
    BLOCK = {'SRQS8F7JWA9MZ|Beyond Burger'}          # matched Telway Burger's description
    hit = 0
    for r in R:
        k, d = define(r['item'])
        r['definition'] = d
        r['definition_of'] = k
        if d:
            hit += 1
        key = f"{r['loc']}|{r['item']}"
        if key in MAN:
            r['menu_desc'] = MAN[key]
            r['menu_src'] = 'restaurant website'
        elif key in MM and r['loc'] in TRUST and key not in BLOCK:
            r['menu_desc'] = MM[key]['desc']
            r['menu_src'] = 'menu file'
        else:
            r['menu_desc'] = None
            r['menu_src'] = None
    json.dump(R, open(os.path.join(H, 'corrections.json'), 'w'), indent=1)
    items = {(r['loc'], r['item']) for r in R}
    defined = {(r['loc'], r['item']) for r in R if r['definition']}
    menued = {(r['loc'], r['item']) for r in R if r['menu_desc']}
    print(f'{len(R)} decisions over {len(items)} unique items')
    print(f'  with a dictionary definition : {len(defined)} items  ({hit} decisions)')
    print(f'  with a real menu description : {len(menued)} items')
    print(f'  with neither                 : {len(items - defined - menued)} items')
    miss = sorted(items - defined - menued)
    print('\nno definition (proprietary or unrecognised names):')
    for l, i in miss[:24]:
        print(f'    {l[:8]:9} {i[:44]}')
    if len(miss) > 24:
        print(f'    ... and {len(miss)-24} more')
