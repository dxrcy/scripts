#!/usr/bin/env nu

# TODO: Implement `mt` with `wpctl` (removes `pactl` dependency)
# TODO: Use `brightnessctl` options `--exponent` etc

let config = {
    volume: {
        step: 5
        max: 100
        balance_right: 98 # Percentage modifier of right channel, to left
    }
    brightness: {
        amount_small: 1
        amount_large: 5
        # TODO: Instead of two thresholds, round to multiple of step amount
        threshold_min: 5
        threshold_max: 10
    }
    notification: {
        timeout: 1000
        unique_id: 5818
    }
    icon: {
        volume_mute: ""
        volume_low: ""
        volume_high: ""
        brightness: ""
        microphone_mute: ""
        microphone_on: ""
    }
}

def main []: nothing -> nothing {
    help main
}

def "main volume"      []: nothing -> nothing { main }
def "main mute"        []: nothing -> nothing { main }
def "main microphones" []: nothing -> nothing { main }
def "main brightness"  []: nothing -> nothing { main }

def "main volume up" []: nothing -> nothing {
    mute set-disabled
    volume set ((volume get) + $config.volume.step | clamp-percent)
    notify volume
}
def "main volume down" []: nothing -> nothing {
    mute set-disabled
    volume set ((volume get) - $config.volume.step | clamp-percent)
    notify volume
}
def "main mute toggle" []: nothing -> nothing {
    mute toggle
    notify volume
}
def "main microphones toggle" []: nothing -> nothing {
    microphones toggle
    notify microphone
}
def "main microphones disable" []: nothing -> nothing {
    microphones set-enabled false
    notify microphone
}
def "main microphones enable" []: nothing -> nothing {
    microphones set-enabled true
    notify microphone
}
def "main brightness up" []: nothing -> nothing {
    brightness set (brightness get | smart-step increase $config.brightness)
    notify brightess
}
def "main brightness down" []: nothing -> nothing {
    brightness set (brightness get | smart-step decrease $config.brightness)
    notify brightess
}

def "volume get" []: nothing -> float {
    (wpctl get-volume @DEFAULT_SINK@
        | split column " "
        | get 0.column1
        | into float
    ) * 100
}

def "volume set" [value: float]: nothing -> nothing {
    let value_left = $value
    let value_right = ($value * $config.volume.balance_right / 100.0)
    amixer sset Master $"($value_left)%,($value_right)%"
}

def "mute is-enabled" []: nothing -> bool {
    wpctl get-volume @DEFAULT_SINK@ | str contains "[MUTED]"
}

def "mute set-disabled" []: nothing -> nothing {
    wpctl set-mute @DEFAULT_SINK@ 0
}

def "mute toggle" []: nothing -> nothing {
    wpctl set-mute @DEFAULT_SINK@ toggle
}

def "microphones is-enabled" []: nothing -> bool {
    pactl list sources | str contains "Mute: yes"
}

def "microphones set-enabled" [enable: bool]: nothing -> nothing {
    let state = if $enable { "yes" } else { "no" }
    for source in (pactl list short sources
        | lines
        | each { split column "\t"
            | get column1.0
        }
    ) {
        pactl set-source-mute $source $state
    }
}

def "microphones toggle" []: nothing -> nothing {
    microphones set-enabled (not (microphones is-enabled))
}

def "brightness get" []: nothing -> float {
    let value = (brightnessctl get | into float)
    let max = (brightnessctl max | into float)
    echo (100 * $value / $max)
}

def "brightness set" [value: float]: nothing -> nothing {
    brightnessctl set $"($value)%"
}

def "notify volume" []: nothing -> nothing {
    let value = (volume get)
    let icon = if ($value == 0) or (mute is-enabled) {
            $config.icon.volume_mute
        } else if $value < 50 {
            $config.icon.volume_low
        } else {
            $config.icon.volume_high
        }
    notify-progress $value $icon
}

def "notify microphone" []: nothing -> nothing {
    let text = if (microphones is-enabled) {
        "Microphone ENABLED" } else { "Microphone disabled" }
    let icon = if (microphones is-enabled) {
        $config.icon.microphone_on } else { $config.icon.microphone_mute }
    notify-inner $text $icon
}

def "notify brightess" []: nothing -> nothing {
    notify-progress (brightness get) $config.icon.brightness
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

def "smart-step increase" [params: record]: float -> float {
    if $in >= $params.threshold_max {
        ($in + $params.amount_large)
    } else if $in + $params.amount_small > $params.threshold_min {
        ($params.threshold_max | into float)
    } else {
        ($in + $params.amount_small)
    }
}

def "smart-step decrease" [params: record]: float -> float {
    if $in > $params.threshold_max {
        ($in - $params.amount_large)
    } else if $in - $params.amount_small > $params.threshold_min {
        ($params.threshold_min | into float)
    } else {
        ($in - $params.amount_small)
    }
}

def notify-progress [value: float, icon: string]: nothing -> nothing {
    (notify-inner $"($value | math round)%" $icon
        --hints $"int:value:($value)"
    )
}

def --wrapped notify-inner [
    text: string,
    icon: string,
    ...args,
]: nothing -> nothing {
    (dunstify
        $"($icon) ($text)"
        --icon none
        --timeout $config.notification.timeout
        --urgency normal
        --replace $config.notification.unique_id
        ...$args
    )
}
