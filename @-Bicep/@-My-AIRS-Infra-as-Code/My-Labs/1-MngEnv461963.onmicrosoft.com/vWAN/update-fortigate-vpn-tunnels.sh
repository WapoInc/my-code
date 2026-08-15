config vpn ipsec phase1-interface
    edit "MiaCasa-Fort-1"
        set remote-gw 4.253.125.184
    next
    edit "MiaCasa-Fort-2"
        set remote-gw 4.253.6.166
    next
end
