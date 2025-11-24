# 🤝 Trusted Job Referrals on Blockchain

A decentralized platform for verifiable professional referrals and endorsements built on Stacks blockchain.

## 🎯 Features

- Create professional profiles
- Issue and receive trusted job referrals
- Verify profile authenticity
- Track referral counts
- Immutable referral records

## 🛠 Usage

### Creating a Profile
```clarity
(contract-call? .trusted-job-referrals create-profile "John Doe" "Senior Developer" "Tech Corp")
```

### Adding a Referral
```clarity
(contract-call? .trusted-job-referrals add-referral 
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
    "Software Engineer"
    "Tech Corp"
    "Direct Manager"
    "Excellent team player with strong technical skills"
    u1577836800
    u1609459200
)
```

### Viewing Referrals
```clarity
(contract-call? .trusted-job-referrals get-referral 
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
    'SP1P72Z3704VMT3DMHPP2CB8TGQWGDBHD3RPR9GZS
)
```

## 🔒 Security

- Only verified profiles can issue referrals
- One referral per referrer-candidate pair
- Self-referrals prevented
- Immutable referral records

## 🚀 Getting Started

1. Clone the repository
2. Install Clarinet
3. Run `clarinet console`
4. Deploy contract
5. Start issuing verifiable referrals!

## 📝 License

MIT
```
