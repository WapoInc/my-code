config vpn ipsec phase1-interface
    edit "MiaCasa-Fort-1"
        set remote-gw 4.253.18.143
    next
    edit "MiaCasa-Fort-2"
        set remote-gw 4.253.18.145
    next
end
