/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/**/*.gleam'],
  theme: {
    extend: {},
  },
  plugins: [require('daisyui')],
  daisyui: {
    themes: ["light"],
  },
}
