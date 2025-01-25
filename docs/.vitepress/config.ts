import { defineConfig } from "vitepress";
import { tabsMarkdownPlugin } from 'vitepress-plugin-tabs'

// https://vitepress.dev/reference/site-config
export default defineConfig({

    title: "skilift",
    titleTemplate: ":title - Datastore library",
    description: "Datastore library without any session locking and with transactions!",
    base: "/skilift/",
    head: [
        ["link", { rel: "icon", href: "/skilift/logo.svg" }],
        ["link", { rel: "preconnect", href: "https://fonts.googleapis.com" }],
        ["link", { rel: "preconnect", href: "https://fonts.gstatic.com", crossorgin: '' }],
        ["link", { rel: "stylesheet", href: "https://fonts.googleapis.com/css2?family=JetBrains+Mono:ital,wght@0,100..800;1,100..800&display=swap" }]
    ],
    cleanUrls: true,

    vite: {
        ssr: {
            noExternal: [
                '@nolebase/vitepress-plugin-highlight-targeted-heading'
            ]
        }
    },
    
    markdown: {
        config(md) {
            md.use(tabsMarkdownPlugin);
        }
    },

    themeConfig: {
        logo: "/skilift.svg",

        search: {
            provider: "local"
        },

        footer: {
            message: 'Released under the MIT License.',
        },

        // https://vitepress.dev/reference/default-theme-config
        nav: [
            { text: "Home", link: "/" },
            { text: "Resources", link: "/resources/getting-started/1-why/" },
            { text: "API", link: "/api/skilift/"},
        ],

        sidebar: {
            "/api/": [
                { text: "skilift", link: "/api/skilift/" },
                { text: "store", link: "/api/store/" },
                { text: "session", link: "/api/session/" },
                { text: "view", link: "/api/view/" },
            ],
            "/resources/": [
                { text: "Getting Started", collapsed: false, items: [
                    { text: "Why", link: "/resources/getting-started/1-why/" },
                    { text: "Installation", link: "/resources/getting-started/2-installation/" },
                    { text: "Setting Up", link: "/resources/getting-started/3-setting-up/" },
                ] },
                { text: "Concepts", collapsed: false, items: [
                    { text: "Transactions", link: "/resources/advanced-concepts/transactions/" },
                    { text: "Migrations", link: "/resources/advanced-concepts/migrations/" },
                    { text: "Strict Mode", link: "/resources/advanced-concepts/strict-mode/" },
                ] },
            ]
        },

        socialLinks: [
            { icon: "github", link: "https://github.com/alicesaidhi/skilift" }
        ]
    }
})