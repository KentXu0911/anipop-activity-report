local TicketNumAnimConfig = {}

function TicketNumAnimConfig:createSwitchConfig()
    return {
        name = "ticketNumSwitch",
        duration = 0.3333,
        tracks = {
            {
                target = "oldNum",
                type = "scale",
                init = {scale = {x = 1, y = 1}},
                keyframes = {
                    {time = 0, scale = {x = 1.05, y = 1.05}, duration = 0.0667, easing = "easeIn"},
                    {time = 0.0667, scale = {x = 0.9, y = 0.9}, duration = 0.0666, easing = "easeIn"},
                },
            },
            {
                target = "oldNum",
                type = "alpha",
                keyframes = {
                    {time = 0, alpha = 255, duration = 0},
                    {time = 0.1333, alpha = 255, duration = 0},
                    {time = 0.1333, alpha = 0, duration = 0.0334, easing = "easeIn"},
                },
            },
            {
                target = "newNum",
                type = "scale",
                keyframes = {
                    {time = 0, scale = {x = 0.8, y = 0.8}, duration = 0},
                    {time = 0.1333, scale = {x = 0.8, y = 0.8}, duration = 0},
                    {time = 0.1333, scale = {x = 1.15, y = 1.15}, duration = 0.0667, easing = "easeIn"},
                    {time = 0.2, scale = {x = 1, y = 1}, duration = 0.1333, easing = "easeIn"},
                },
            },
            {
                target = "newNum",
                type = "alpha",
                keyframes = {
                    {time = 0, alpha = 0, duration = 0},
                    {time = 0.1333, alpha = 0, duration = 0},
                    {time = 0.1333, alpha = 255, duration = 0.0334, easing = "easeIn"},
                },
            },
        },
    }
end

return TicketNumAnimConfig
