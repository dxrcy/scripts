#!/usr/bin/nu

let config = {
    volume: {
        step: 5
        max: 100
        balance_right: 98 # Percentage modifier of right channel, to left
    }
    brightness: {
        amount_small: 1
        amount_large: 5
        threshold_min: 5
        threshold_max: 10
    }
    notification: {
        timeout: 1000
        unique_id: 5818
    }
    icon: {
        volume_mute: ''
        volume_low: ''
        volume_high: ''
        brightness: ""
    }
}

def main [] { }

def "main v+" [] {
    set-volume ((get-volume) + $config.volume.step | clamp-percent)
    notify-volume
}

def "main v-" [] {
    set-volume ((get-volume) - $config.volume.step | clamp-percent)
    notify-volume
}

def "main b+" [] {
    set-brightness (get-brightness | smart-step increase $config.brightness)
    notify-brightess
}

def "main b-" [] {
    set-brightness (get-brightness | smart-step decrease $config.brightness)
    notify-brightess
}

def get-volume []: nothing -> float {
    (wpctl get-volume @DEFAULT_SINK@
        | split column ' '
        | get 0.column1
        | into float
    ) * 100
}

def get-brightness []: nothing -> float {
    let value = (brightnessctl get | into float)
    let max = (brightnessctl max | into float)
    echo (100 * $value / $max)
}

def set-volume [value: float] {
    let value_left = $value
    let value_right = ($value * $config.volume.balance_right / 100.0)
    amixer sset Master $"($value_left)%,($value_right)%"
}

def set-brightness [value: float] {
    brightnessctl set $"($value)%"
}

def notify-volume [] {
    let value = (get-volume)
    let icon = if $value == 0 {
            $config.icon.volume_mute
        } else if $value < 50 {
            $config.icon.volume_low
        } else {
            $config.icon.volume_high
        }
    notify-progress $value $icon
}

def notify-brightess [] {
    notify-progress (get-brightness) $config.icon.brightness
}

def clamp-percent []: float -> float {
    if $in < 0 {
        0.0
    } else if $in > 100 {
        100.0
    } else {
        $in
    }
}

def "smart-step increase" [params]: float -> float {
    if $in >= $params.threshold_max {
        ($in + $params.amount_large)
    } else if $in + $params.amount_small > $params.threshold_min {
        ($params.threshold_max)
    } else {
        ($in + $params.amount_small)
    }
}

def "smart-step decrease" [params]: float -> float {
    if $in > $params.threshold_max {
        ($in - $params.amount_large)
    } else if $in - $params.amount_small > $params.threshold_min {
        ($params.threshold_min)
    } else {
        ($in - $params.amount_small)
    }
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
