# 📐 Architecture Diagrams

This folder contains all system architecture diagrams for the CNM Zalo Clone project.

## 🎨 Available Diagrams

### 1. System Architecture
- **File**: `system-architecture.drawio.svg`
- **Type**: Complete system overview
- **Tool**: Draw.io / Diagrams.net
- **Editable**: Yes (open with Draw.io VS Code extension)

### 2. Microservices Detail
- **File**: `microservices-detail.png`
- **Type**: 16 services breakdown
- **Tool**: Eraser.io / Lucidchart

### 3. Message Flow
- **File**: `message-flow.md`
- **Type**: Sequence diagram
- **Tool**: Mermaid / PlantUML

### 4. Data Architecture
- **File**: `data-architecture.drawio.svg`
- **Type**: Database schema & relationships
- **Tool**: Draw.io

### 5. Deployment Architecture
- **File**: `deployment-k8s.png`
- **Type**: Kubernetes deployment
- **Tool**: Cloudcraft / Lucidchart

---

## 🔗 External Links

### Eraser.io Workspace
**Main Architecture Diagram**: https://app.eraser.io/workspace/Ve76SGuLI2AJRqTvcXRZ

**How to access:**
1. Sign in to Eraser.io with GitHub
2. Join workspace: CNM-Zalo-Clone
3. View/Edit diagrams collaboratively

### Lucidchart (Alternative)
**Link**: https://lucid.app/[YOUR_CHART_ID]

---

## 🛠️ How to Edit Diagrams

### Using Draw.io in VS Code

1. Install extension:
   ```bash
   code --install-extension hediet.vscode-drawio
   ```

2. Open `.drawio.svg` file
3. Edit directly in VS Code
4. Save (auto-exports to SVG)

### Using Eraser.io

1. Go to: https://app.eraser.io
2. Import existing diagram or create new
3. Collaborate with team
4. Export as PNG/SVG
5. Save to `docs/diagrams/`

### Using PlantUML

1. Install extension:
   ```bash
   code --install-extension jebbs.plantuml
   ```

2. Edit `.puml` file
3. Preview: `Alt+D`
4. Export: Right-click → Export

---

## 📋 Diagram Conventions

### Colors
- 🔵 **Blue**: Authentication & Security services
- 🟢 **Green**: Social & Community services
- 🟣 **Purple**: Messaging & Real-time services
- 🟠 **Orange**: Extended features & AI services
- ⚫ **Gray**: Infrastructure (Databases, Kafka, Redis)

### Icons
- 📱 Mobile clients
- 🌐 Web clients
- ⚖️ Load balancers
- 🚪 API Gateway
- 🔐 Auth services
- 💬 Message services
- 📊 Databases
- 📨 Message queues

### Arrows
- **Solid lines** → Synchronous calls (HTTP/REST)
- **Dashed lines** ⇢ Asynchronous events (Kafka)
- **Bold lines** ⟹ Data flow
- **Bidirectional** ↔ WebSocket connections

---

## 📦 Export Formats

All diagrams should be available in:
- ✅ **SVG** - Scalable, Git-friendly
- ✅ **PNG** - High-resolution (300dpi)
- ✅ **PDF** - For documentation
- ✅ **Source** - Editable format (.drawio, .puml, etc.)

---

## 🔄 Update Process

1. **Edit diagram** using preferred tool
2. **Export** in multiple formats
3. **Update this README** if adding new diagram
4. **Commit changes** to Git
5. **Update links** in main README.md

---

## 📚 Resources

### Diagram Tools
- [Eraser.io](https://app.eraser.io) - AI-powered diagrams
- [Draw.io](https://app.diagrams.net) - Free diagramming
- [Lucidchart](https://lucid.app) - Professional diagrams
- [PlantUML](https://plantuml.com) - Text-based diagrams
- [Cloudcraft](https://cloudcraft.co) - AWS architecture

### Icon Libraries
- [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/)
- [Kubernetes Icons](https://kubernetes.io/docs/contribute/style/diagram-guide/)
- [Font Awesome](https://fontawesome.com) - General icons
- [Lucidchart Icons](https://www.lucidchart.com/pages/templates)

---

**Last Updated**: January 25, 2026
**Maintained by**: Architecture Team
