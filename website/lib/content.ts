// Central content source so sections stay data-driven and reusable.

export interface NavLink {
  label: string;
  href: string;
}

export type MenuCategory =
  | 'Breakfast'
  | 'Starters'
  | 'Main Meals'
  | 'Fish'
  | 'Pasta & Salads'
  | 'Desserts'
  | 'Drinks';

export interface MenuItem {
  id: string;
  name: string;
  desc: string;
  price: number;
  rating: number;
  tag: string;
  category: MenuCategory;
  image: string;
}

export interface StoryReel {
  id: string;
  title: string;
  image: string;
  likes: string;
  comments: string;
}

export interface HeroDish {
  name: string;
  price: number;
  rating: number;
  image: string;
}

export const NAV_LINKS: NavLink[] = [
  { label: 'Menu', href: '/menu' },
  { label: 'About', href: '/about' },
  { label: 'Contact', href: '#footer' },
];

// Unsplash imagery — sized via query params for responsive delivery.
const img = (id: string, w = 800): string =>
  `https://images.unsplash.com/photo-${id}?auto=format&fit=crop&w=${w}&q=70`;

export const HERO_DISH: HeroDish = {
  name: 'Wood-fired Sea Bass',
  price: 32,
  rating: 4.9,
  image: img('1467003909585-2f8a72700288', 700),
};

export const MARQUEE_ITEMS: string[] = [
  'Raw Bar',
  'Small Plates',
  'Salads',
  'Starters',
  'Mains',
  'Sides',
  'Appetizers',
  'Sandwiches',
  'Entrées',
  'House Cocktails',
  'Draft Beer',
  'Wine',
];

export const ABOUT_IMAGES: { primary: string; secondary: string } = {
  primary: img('1414235077428-338989a2e8c0', 700), // dining ambiance
  secondary: img('1555396273-367ea4eb4db5', 600), // chef plating
};

export const MENU_CATEGORIES: MenuCategory[] = [
  'Breakfast',
  'Starters',
  'Main Meals',
  'Fish',
  'Pasta & Salads',
  'Desserts',
  'Drinks',
];

export const MENU_ITEMS: MenuItem[] = [
  {
    id: 'm1',
    name: 'Truffle Risotto',
    desc: 'Carnaroli rice, black truffle, aged parmesan, herb oil.',
    price: 26,
    rating: 4.8,
    tag: 'Chef’s Pick',
    category: 'Main Meals',
    image: img('1476124369491-e7addf5db371', 700),
  },
  {
    id: 'm2',
    name: 'Charred Octopus',
    desc: 'Spanish octopus, smoked paprika, salsa verde, fingerling potato.',
    price: 29,
    rating: 4.9,
    tag: 'Popular',
    category: 'Fish',
    image: img('1565299624946-b28f40a0ae38', 700),
  },
  {
    id: 'm3',
    name: 'Dry-aged Ribeye',
    desc: '45-day aged ribeye, bone marrow butter, charred shallot.',
    price: 48,
    rating: 5.0,
    tag: 'Signature',
    category: 'Main Meals',
    image: img('1546964124-0cce460f38ef', 700),
  },
  {
    id: 'm4',
    name: 'Garden Burrata',
    desc: 'Creamy burrata, heirloom tomato, basil, aged balsamic.',
    price: 19,
    rating: 4.7,
    tag: 'Vegetarian',
    category: 'Starters',
    image: img('1608897013039-887f21d8c804', 700),
  },
  {
    id: 'm5',
    name: 'Saffron Paella',
    desc: 'Bomba rice, prawns, mussels, chorizo, saffron broth.',
    price: 34,
    rating: 4.8,
    tag: 'Sharing',
    category: 'Fish',
    image: img('1534080564583-6be75777b70a', 700),
  },
  {
    id: 'm6',
    name: 'Dark Chocolate Tart',
    desc: '70% ganache, sea salt, olive oil, crème fraîche.',
    price: 14,
    rating: 4.9,
    tag: 'Dessert',
    category: 'Desserts',
    image: img('1571877227200-a0d98ea607e9', 700),
  },
  {
    id: 'm7',
    name: 'Shakshuka & Eggs',
    desc: 'Slow-cooked tomato, peppers, baked eggs, warm flatbread.',
    price: 16,
    rating: 4.8,
    tag: 'Brunch',
    category: 'Breakfast',
    image: img('1590412200988-a436970781fa', 700),
  },
  {
    id: 'm8',
    name: 'Heirloom Tomato Salad',
    desc: 'Vine tomatoes, stracciatella, basil oil, toasted pine nuts.',
    price: 17,
    rating: 4.7,
    tag: 'Fresh',
    category: 'Pasta & Salads',
    image: img('1512621776951-a57141f2eefd', 700),
  },
  {
    id: 'm9',
    name: 'Pomegranate Spritz',
    desc: 'Pomegranate, prosecco, citrus, fresh mint, soda.',
    price: 12,
    rating: 4.9,
    tag: 'Signature',
    category: 'Drinks',
    image: img('1551024709-8f23befc6f87', 700),
  },
  {
    id: 'm10',
    name: 'Avocado Toast',
    desc: 'Sourdough, smashed avocado, chili, lemon, soft poached egg.',
    price: 14,
    rating: 4.7,
    tag: 'Brunch',
    category: 'Breakfast',
    image: img('1513104890138-7c749659a591', 700),
  },
  {
    id: 'm11',
    name: 'Buttermilk Pancakes',
    desc: 'Stacked pancakes, maple butter, seasonal berries.',
    price: 13,
    rating: 4.8,
    tag: 'Sweet',
    category: 'Breakfast',
    image: img('1473093295043-cdd812d0e601', 700),
  },
  {
    id: 'm12',
    name: 'Roasted Tomato Soup',
    desc: 'Slow-roasted tomato, basil oil, sourdough crouton.',
    price: 11,
    rating: 4.6,
    tag: 'Warm',
    category: 'Starters',
    image: img('1556910103-1c02745aae4d', 700),
  },
  {
    id: 'm13',
    name: 'Crispy Calamari',
    desc: 'Lightly fried squid, lemon aioli, fresh herbs.',
    price: 16,
    rating: 4.8,
    tag: 'Popular',
    category: 'Starters',
    image: img('1565299624946-b28f40a0ae38', 700),
  },
  {
    id: 'm14',
    name: 'Herb Roast Chicken',
    desc: 'Free-range chicken, lemon, thyme, roasted potatoes.',
    price: 28,
    rating: 4.7,
    tag: 'Classic',
    category: 'Main Meals',
    image: img('1504674900247-0877df9cc836', 700),
  },
  {
    id: 'm15',
    name: 'Grilled Sea Bass',
    desc: 'Whole sea bass, salsa verde, charred lemon, fennel.',
    price: 32,
    rating: 4.9,
    tag: 'Chef’s Pick',
    category: 'Fish',
    image: img('1467003909585-2f8a72700288', 700),
  },
  {
    id: 'm16',
    name: 'Tagliatelle al Ragù',
    desc: 'House-made pasta, slow-cooked beef ragù, parmesan.',
    price: 23,
    rating: 4.8,
    tag: 'Popular',
    category: 'Pasta & Salads',
    image: img('1551183053-bf91a1d81141', 700),
  },
  {
    id: 'm17',
    name: 'Caesar Salad',
    desc: 'Baby gem, anchovy dressing, parmesan, sourdough croutons.',
    price: 15,
    rating: 4.6,
    tag: 'Fresh',
    category: 'Pasta & Salads',
    image: img('1512621776951-a57141f2eefd', 700),
  },
  {
    id: 'm18',
    name: 'Classic Tiramisu',
    desc: 'Espresso-soaked savoiardi, mascarpone, cocoa.',
    price: 13,
    rating: 4.9,
    tag: 'Signature',
    category: 'Desserts',
    image: img('1571877227200-a0d98ea607e9', 700),
  },
  {
    id: 'm19',
    name: 'Lemon Cheesecake',
    desc: 'Baked vanilla cheesecake, lemon curd, shortbread base.',
    price: 12,
    rating: 4.7,
    tag: 'Sweet',
    category: 'Desserts',
    image: img('1473093295043-cdd812d0e601', 700),
  },
  {
    id: 'm20',
    name: 'Espresso Martini',
    desc: 'Vodka, fresh espresso, coffee liqueur, vanilla.',
    price: 14,
    rating: 4.9,
    tag: 'Popular',
    category: 'Drinks',
    image: img('1466978913421-dad2ebd01d17', 700),
  },
  {
    id: 'm21',
    name: 'Aperol Sunset',
    desc: 'Aperol, prosecco, soda, blood orange, rosemary.',
    price: 12,
    rating: 4.7,
    tag: 'Refreshing',
    category: 'Drinks',
    image: img('1525755662778-989d0524087e', 700),
  },
];

export const STORY_REELS: StoryReel[] = [
  {
    id: 's1',
    title: 'Behind the Secrets of the Stove and the Kitchen',
    image: img('1556910103-1c02745aae4d', 600),
    likes: '5M',
    comments: '10k',
  },
  {
    id: 's2',
    title: 'Where Culinary Art Truly Meets Heart at Dinevo',
    image: img('1513104890138-7c749659a591', 600),
    likes: '3.6M',
    comments: '5k',
  },
  {
    id: 's3',
    title: 'Stories of Flavor, Fire, and Inspiration at Dinevo',
    image: img('1517248135467-4c7edcad34c4', 600),
    likes: '4M',
    comments: '10k',
  },
  {
    id: 's4',
    title: 'Tales of Taste, Craft, and Creativity at Dinevo',
    image: img('1559339352-11d035aa65de', 600),
    likes: '7M',
    comments: '18k',
  },
  {
    id: 's5',
    title: 'The Craft and Creativity that Define Dinevo',
    image: img('1473093295043-cdd812d0e601', 600),
    likes: '1.3M',
    comments: '2.1k',
  },
  {
    id: 's6',
    title: 'The Passion Behind Every Plate at Dinevo',
    image: img('1565299624946-b28f40a0ae38', 600),
    likes: '2M',
    comments: '4.5k',
  },
];
