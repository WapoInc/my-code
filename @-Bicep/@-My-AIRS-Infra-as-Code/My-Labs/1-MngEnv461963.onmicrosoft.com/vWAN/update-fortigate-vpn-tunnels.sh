config vpn ipsec phase1-interface
    edit "MiaCasa-Fort-1"
        set remote-gw 4.253.73.228
    next
    edit "MiaCasa-Fort-2"
        set remote-gw 40.127.3.108
    next
end
