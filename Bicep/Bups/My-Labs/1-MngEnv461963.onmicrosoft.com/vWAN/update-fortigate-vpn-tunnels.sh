config vpn ipsec phase1-interface
    edit "MiaCasa-Fort-1"
        set remote-gw 4.253.93.14
    next
    edit "MiaCasa-Fort-2"
        set remote-gw 20.87.56.232
    next
end
