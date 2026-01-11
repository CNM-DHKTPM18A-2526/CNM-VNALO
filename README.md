<p align="center">
  <img src="https://img.icons8.com/color/128/chat--v1.png" alt="ZaloClone Logo" width="100"/>
</p>

<h1 align="center">🚀 ZaloClone - OTT Messaging Platform</h1>

<p align="center">
  <strong>A modern, scalable, real-time messaging application inspired by Zalo</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#tech-stack">Tech Stack</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#documentation">Docs</a> •
  <a href="#contributing">Contributing</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue.svg" alt="Version"/>
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"/>
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome"/>
  <img src="https://img.shields.io/badge/status-in%20development-orange.svg" alt="Status"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Java-21-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white" alt="Java"/>
  <img src="https://img.shields.io/badge/Spring%20Boot-3.x-6DB33F?style=for-the-badge&logo=spring&logoColor=white" alt="Spring Boot"/>
  <img src="https://img.shields.io/badge/React%20Native-0.76-61DAFB?style=for-the-badge&logo=react&logoColor=black" alt="React Native"/>
  <img src="https://img.shields.io/badge/PostgreSQL-16-316192?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL"/>
  <img src="https://img.shields.io/badge/Apache%20Kafka-3.x-231F20?style=for-the-badge&logo=apachekafka&logoColor=white" alt="Kafka"/>
</p>

---

## ✨ Features

<table>
  <tr>
    <td>
      <h3>💬 Messaging</h3>
      <ul>
        <li>Real-time 1:1 & Group chat</li>
        <li>Text, Images, Videos, Files</li>
        <li>Reply & Forward messages</li>
        <li>Emoji reactions</li>
        <li>Recall messages</li>
        <li>Typing indicators</li>
        <li>Read receipts</li>
      </ul>
    </td>
    <td>
      <h3>👥 Social</h3>
      <ul>
        <li>Phone number authentication</li>
        <li>Friend requests</li>
        <li>User profiles</li>
        <li>Online/Offline status</li>
        <li>Block/Unblock users</li>
        <li>Contact sync</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td>
      <h3>👨‍👩‍👧‍👦 Groups</h3>
      <ul>
        <li>Create groups</li>
        <li>Add/Remove members</li>
        <li>Admin roles</li>
        <li>Group settings</li>
        <li>@Mention members</li>
      </ul>
    </td>
    <td>
      <h3>🔔 Notifications</h3>
      <ul>
        <li>Push notifications (FCM)</li>
        <li>Mute conversations</li>
        <li>Unread badges</li>
        <li>Sound settings</li>
      </ul>
    </td>
  </tr>
</table>

---

## 🛠 Tech Stack

### Backend
| Technology | Purpose |
|------------|---------|
| **Java 21** | Core language |
| **Spring Boot 3.x** | Microservices framework |
| **Spring Security** | Authentication & Authorization |
| **Netty** | WebSocket realtime gateway |
| **Apache Kafka** | Event streaming |
| **PostgreSQL** | Primary database |
| **Apache Cassandra** | Message storage |
| **Redis** | Caching & Presence |
| **Firebase Admin** | Phone OTP verification |
| **AWS S3** | Media storage |

### Frontend
| Technology | Purpose |
|------------|---------|
| **React Native 0.76+** | Cross-platform mobile |
| **TypeScript** | Type safety |
| **Zustand** | State management |
| **React Query** | Server state |
| **React Navigation** | Navigation |
| **NativeWind** | Styling (TailwindCSS) |

### DevOps
| Technology | Purpose |
|------------|---------|
| **Docker** | Containerization |
| **Kubernetes (EKS)** | Orchestration |
| **GitHub Actions** | CI/CD |
| **Terraform** | Infrastructure as Code |
| **Prometheus + Grafana** | Monitoring |

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENTS                                  │
│              iOS    Android    Web (Future)                     │
└───────────────────────────┬─────────────────────────────────────┘
                            │
              ┌─────────────┴─────────────┐
              │      AWS Cloud            │
              │  ┌─────────┐ ┌─────────┐  │
              │  │   ALB   │ │   NLB   │  │
              │  │ (REST)  │ │  (WS)   │  │
              │  └────┬────┘ └────┬────┘  │
              │       │           │       │
              │  ┌────┴───────────┴────┐  │
              │  │   Kubernetes (EKS)  │  │
              │  │                     │  │
              │  │  ┌──────────────┐   │  │
              │  │  │ API Gateway  │   │  │
              │  │  └──────┬───────┘   │  │
              │  │         │           │  │
              │  │  ┌──────┴───────┐   │  │
              │  │  │ Microservices│   │  │
              │  │  │ • Auth       │   │  │
              │  │  │ • User       │   │  │
              │  │  │ • Social     │   │  │
              │  │  │ • Message    │   │  │
              │  │  │ • Media      │   │  │
              │  │  │ • Notify     │   │  │
              │  │  └──────────────┘   │  │
              │  │                     │  │
              │  │  ┌──────────────┐   │  │
              │  │  │Realtime GW   │   │  │
              │  │  │  (Netty)     │   │  │
              │  │  └──────────────┘   │  │
              │  └─────────────────────┘  │
              │                           │
              │  ┌─────┐ ┌─────┐ ┌─────┐  │
              │  │ RDS │ │Redis│ │Kafka│  │
              │  └─────┘ └─────┘ └─────┘  │
              │                           │
              │  ┌─────────┐ ┌─────────┐  │
              │  │Cassandra│ │   S3    │  │
              │  └─────────┘ └─────────┘  │
              └───────────────────────────┘
```

---

## 🚀 Getting Started

### Prerequisites

- Java 21+
- Node.js 20+
- Docker & Docker Compose
- Android Studio / Xcode (for mobile development)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/your-username/cnm-zalo-clone.git
cd cnm-zalo-clone

# Start infrastructure services
docker compose up -d

# Backend (coming soon)
cd backend
./gradlew bootRun

# Mobile app (coming soon)
cd frontend/mobile
npm install
npm run android  # or npm run ios
```

---

## 📁 Project Structure

```
cnm-zalo-clone/
├── 📂 docs/                    # Documentation
│   └── OTT_AI_Agent_Project_Docs.md
├── 📂 backend/                 # Backend services
│   ├── services/               # Microservices
│   ├── realtime-gateway/       # Netty WebSocket server
│   └── shared/                 # Shared libraries
├── 📂 frontend/                # Frontend applications
│   ├── mobile/                 # React Native app
│   └── web/                    # Web app (future)
├── 📂 k8s/                     # Kubernetes manifests
├── 📂 terraform/               # Infrastructure as Code
├── 📂 scripts/                 # Utility scripts
├── 📄 docker-compose.yml       # Local development
├── 📄 .gitignore
└── 📄 README.md
```

---

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [Project Documentation](docs/OTT_AI_Agent_Project_Docs.md) | Comprehensive project documentation |
| API Reference | Coming soon |
| Mobile App Guide | Coming soon |
| Deployment Guide | Coming soon |

---

## 🗺 Roadmap

- [x] Project setup & documentation
- [ ] **Phase 1**: Authentication & User Profile
- [ ] **Phase 2**: Social Graph (Friends, Contacts)
- [ ] **Phase 3**: 1:1 Chat with realtime messaging
- [ ] **Phase 4**: Group Chat
- [ ] **Phase 5**: Media sharing (Images, Videos, Files)
- [ ] **Phase 6**: Push Notifications
- [ ] **Phase 7**: Polish & Performance
- [ ] **Future**: Voice/Video calls, AI Assistant

---

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting a PR.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat:     New feature
fix:      Bug fix
docs:     Documentation changes
style:    Code style changes (formatting, etc)
refactor: Code refactoring
test:     Adding tests
chore:    Maintenance tasks
```

---

## 👥 Team

| Role | Responsibility |
|------|----------------|
| **Backend Lead** | Auth, User, Social Services |
| **Backend Dev** | Message, Media, Notification Services |
| **Fullstack/Realtime** | Netty Gateway, WebSocket, Infrastructure |
| **Frontend Lead** | React Native App, UI/UX |

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Inspired by [Zalo](https://zalo.me)
- Built with modern technologies and best practices
- Special thanks to all contributors

---

<p align="center">
  Made with ❤️ by the ZaloClone Team
</p>

<p align="center">
  <a href="#top">⬆️ Back to Top</a>
</p>
