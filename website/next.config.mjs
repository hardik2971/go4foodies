/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Static export for Firebase Hosting (go4foodies-restaurant.web.app). Hosting rewrites
  // /api/** to the `api` Cloud Function, so the browser calls the backend same-origin.
  output: 'export',
  images: {
    // No image optimisation server on static hosting; remote photos load directly.
    unoptimized: true,
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'images.unsplash.com',
      },
      {
        protocol: 'https',
        hostname: 'loremflickr.com',
      },
    ],
  },
};

export default nextConfig;
