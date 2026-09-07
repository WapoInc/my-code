config vpn ipsec phase1-interface
    edit "MiaCasa-Fort-1"
        set remote-gw 102.133.130.236
    next
    edit "MiaCasa-Fort-2"
        set remote-gw 4.253.3.227
    next
end
