config vpn ipsec phase1-interface
    edit "MiaCasa-Fort-1"
        set remote-gw 4.253.80.158
    next
    edit "MiaCasa-Fort-2"
        set remote-gw 4.253.195.43
    next
end
