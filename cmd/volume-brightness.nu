#!/usr/bin/nu

# TODO: Implement `mt` with `wpctl` (removes `pactl` dependency)
# TODO: Add function signatures

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

def main [] { }

def "main volume up" [] {
    set-mute unmute
    set-volume ((get-volume) + $config.volume.step | clamp-percent)
    notify-volume
}
def "main volume down" [] {
    set-mute unmute
    set-volume ((get-volume) - $config.volume.step | clamp-percent)
    notify-volume
}
def "main mute toggle" [] {
    set-mute toggle
    notify-volume
}
def "main brightness up" [] {
    set-brightness (get-brightness | smart-step increase $config.brightness)
    notify-brightess
}
def "main brightness down" [] {
    set-brightness (get-brightness | smart-step decrease $config.brightness)
    notify-brightess
}
def "main microphones toggle" [] {
    set-microphones toggle
    notify-microphone
}
def "main microphones disable" [] {
    set-microphones false
    notify-microphone
}
def "main microphones enable" [] {
    set-microphones true
    notify-microphone
}

def get-volume []: nothing -> float {
    (wpctl get-volume @DEFAULT_SINK@
        | split column " "
        | get 0.column1
        | into float
    ) * 100
}

def get-mute []: nothing -> bool {
    wpctl get-volume @DEFAULT_SINK@ | str contains "[MUTED]"
}

def get-brightness []: nothing -> float {
    let value = (brightnessctl get | into float)
    let max = (brightnessctl max | into float)
    echo (100 * $value / $max)
}

def get-microphones []: nothing -> bool {
    pactl list sources | str contains "Mute: yes"
}

def set-volume [value: float] {
    let value_left = $value
    let value_right = ($value * $config.volume.balance_right / 100.0)
    amixer sset Master $"($value_left)%,($value_right)%"
}

def "set-mute unmute" [] {
    wpctl set-mute @DEFAULT_SINK@ 0
}

def "set-mute toggle" [] {
    wpctl set-mute @DEFAULT_SINK@ toggle
}

def set-brightness [value: float] {
    brightnessctl set $"($value)%"
}

def "set-microphones" [enable: bool] {
    let state = if $enable { "yes" } else { "no" }
    for line in (pactl list short sources | lines) {
        let source = ($line | split column "\t" | get column1.0)
        pactl set-source-mute $source $state
    }
}

def "set-microphones toggle" [] {
    if (get-microphones) {
        set-microphones false
    } else {
        set-microphones true
    }
}

def notify-volume [] {
    let value = (get-volume)
    let icon = if ($value == 0) or (get-mute) {
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

def notify-microphone [] {
    let text = if (get-microphones) {
        "Microphone ENABLED" } else { "Microphone disabled" }
    let icon = if (get-microphones) {
        $config.icon.microphone_on } else { $config.icon.microphone_mute }
    notify-inner $text $icon
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
        ($params.threshold_max | into float)
    } else {
        ($in + $params.amount_small)
    }
}

def "smart-step decrease" [params]: float -> float {
    if $in > $params.threshold_max {
        ($in - $params.amount_large)
    } else if $in - $params.amount_small > $params.threshold_min {
        ($params.threshold_min | into float)
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
