config vpn ipsec phase1-interface
    edit "MiaCasa-Fort-1"
        set remote-gw 20.164.125.94
    next
    edit "MiaCasa-Fort-2"
        set remote-gw 20.87.94.37
    next
end
