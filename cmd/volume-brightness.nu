#!/usr/bin/nu

let config = {
    brightness: {
        amount_small: 1
        amount_large: 10
        threshold_min: 5
        threshold_max: 10
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
    let new = (get-brightness | apply-step increase $config.brightness)
    brightnessctl set $"($new)%"
    notify-brightess
}

def "main b-" [] {
    let new = (get-brightness | apply-step decrease $config.brightness)
    brightnessctl set $"($new)%"
    notify-brightess
}

def "apply-step increase" [params]: float -> float {
    if $in >= $params.threshold_max {
        ($in + $params.amount_large)
    } else if $in + $params.amount_small > $params.threshold_min {
        ($params.threshold_max)
    } else {
        ($in + $params.amount_small)
    }
}

def "apply-step decrease" [params]: float -> float {
    if $in > $params.threshold_max {
        ($in - $params.amount_large)
    } else if $in - $params.amount_small > $params.threshold_min {
        ($params.threshold_min)
    } else {
        ($in - $params.amount_small)
    }
}

def get-brightness []: nothing -> float {
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

