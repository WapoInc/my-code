config vpn ipsec phase1-interface
    edit "MiaCasa-Fort-1"
        set remote-gw 20.87.118.33
    next
    edit "MiaCasa-Fort-2"
        set remote-gw 4.253.208.191
    next
end
