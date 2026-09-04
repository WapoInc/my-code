config vpn ipsec phase1-interface
    edit "MiaCasa-Fort-1"
        set remote-gw 20.164.69.28
    next
    edit "MiaCasa-Fort-2"
        set remote-gw 4.253.86.206
    next
end
