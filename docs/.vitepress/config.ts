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
            { text: "Resources", link: "/resources/" },
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
                { text: "Resources", link: "/resources/" },
                { text: "Getting Started", link: "/resources/getting-started/" },
                { text: "Atomic Operations", link: "/resources/atomic-operations/" },
                { text: "Mental Model", link: "/resources/mental-model/" },
                { text: "Transactions", link: "/resources/transactions/" },
                
            ]
        },

        socialLinks: [
            { icon: "github", link: "https://github.com/alicesaidhi/skilift" }
        ]
    }
})