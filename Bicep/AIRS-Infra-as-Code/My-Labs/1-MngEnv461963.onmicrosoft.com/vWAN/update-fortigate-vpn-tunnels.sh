config vpn ipsec phase1-interface
    edit "MiaCasa-Fort-1"
        set remote-gw 4.253.74.250
    next
    edit "MiaCasa-Fort-2"
        set remote-gw 4.253.120.54
    next
end
