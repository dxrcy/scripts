#!/usr/bin/nu

let config = {
    brightness: {
        step_percent: 10
    }
    notification: {
        timeout: 1000
        unique_id: 5818
    }
    icon: {
        brightness: ""
    }
}

def main [] { }

def "main b+" [] {
    brightnessctl set $"($config.brightness.step_percent)%+"
    notify-brightess
}

def "main b-" [] {
    brightnessctl set $"($config.brightness.step_percent)%-"
    notify-brightess
}

def get-brightness [] {
    let value = (brightnessctl get | into float)
    let max = (brightnessctl max | into float)
    echo (100 * $value / $max)
}

def notify-brightess [] {
    let value = (get-brightness)
    notify-progress $value $config.icon.brightness
}

def notify-progress [value: float, icon: string] {
    (notify-inner $"($value | math round)%" $icon
        --hints $"int:value:($value)"
    )
}

def --wrapped notify-inner [text: string, icon: string, ...args] {
    (dunstify
        $"($icon) ($text)"
        --icon none
        --timeout $config.notification.timeout
        --urgency normal
        --replace $config.notification.unique_id
        ...$args
    )
}

