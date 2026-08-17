config vpn ipsec phase1-interface
    edit "MiaCasa-Fort-1"
        set remote-gw 20.87.103.53
    next
    edit "MiaCasa-Fort-2"
        set remote-gw 4.253.162.254
    next
end
