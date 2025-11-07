# Personal Neo4j Memory Server - Enhanced Cloudflare Access Support

A Model Context Protocol (MCP) server that provides AI assistants with persistent, intelligent memory capabilities using Neo4j's graph database with **enhanced Cloudflare Access tunneling support**.

## 🎯 What it does

This server enables AI assistants to:
- **Remember** - Store memories as interconnected knowledge nodes with observations and metadata
- **Search** - Find relevant memories using semantic vector search, exact matching, and graph traversal
- **Connect** - Create meaningful relationships between memories with batch operations and cross-references
- **Organize** - Separate memories by project using different databases
- **Evolve** - Track how knowledge develops over time with temporal metadata and relationship networks
- **🚀 NEW: Reliable Remote Access** - Connect through Cloudflare Zero Trust Access from anywhere

## ✨ Key Features

### Core Capabilities
- 🧠 **Graph Memory** - Memories as nodes, relationships as edges, observations as content
- 🔍 **Unified Search** - Semantic vectors, exact matching, wildcards, and graph traversal in one tool
- 🔗 **Smart Relations** - Typed connections with strength, source tracking, and temporal metadata
- 📊 **Multi-Database** - Isolated project contexts with instant switching
- ☁️ **Cloudflare Access Ready** - Zero Trust tunneling for secure remote connections

### Advanced Operations
- ⚡ **Batch Operations** - Create multiple memories with relationships in single request using localId
- 🎯 **Context Control** - Response detail levels: minimal (lists), full (complete data), relations-only
- 📅 **Time Queries** - Filter by relative ("7d", "30d") or absolute dates on any temporal field
- 🌐 **Graph Traversal** - Navigate networks in any direction with depth control
- 🛡️ **Zero Trust Security** - mTLS encryption through Cloudflare Access

### Architecture
- 🚀 **MCP Native** - Seamless integration with Claude Desktop and MCP clients
- 💾 **Persistent Storage** - Neo4j graph database with GDS plugin for vector operations
- ☁️ **Cloudflare Optimized** - Solved BOLT protocol tunneling issues
- ⚠️ **Zero-Fallback** - Explicit errors for reliable debugging, no silent failures

## 🚀 Quick Start - NPM Installation

### Option 1: Install from NPM (Recommended)
```bash
# Coming soon - after publication
npm install @jeelidev/personal-neo4j-memory-server
```

### Option 2: Install from GitHub (Available Now)
```bash
npx -y https://github.com/jeelidev/personal-neo4j-memory-server.git
```

## 📝 Claude Code Configuration

### Add to Claude Desktop/Claude Code config:

#### For NPM Package (when published):
```json
{
  "mcpServers": {
    "memory": {
      "command": "npx",
      "args": ["-y", "@jeelidev/personal-neo4j-memory-server"],
      "env": {
        "NEO4J_URI": "bolt://localhost:7687",
        "NEO4J_USERNAME": "neo4j",
        "NEO4J_PASSWORD": "your-password"
      }
    }
  }
}
```

#### For GitHub Installation (Current):
```json
{
  "mcpServers": {
    "memory": {
      "command": "npx",
      "args": ["-y", "https://github.com/jeelidev/personal-neo4j-memory-server.git"],
      "env": {
        "NEO4J_URI": "bolt://localhost:7687",
        "NEO4J_USERNAME": "neo4j",
        "NEO4J_PASSWORD": "your-password"
      }
    }
  }
}
```

## ☁️ Cloudflare Access Setup (CRITICAL FOR REMOTE SETUP)

### 🎯 The Problem Solved
Traditional Cloudflare Tunnel with TCP (`cloudflared tunnel --url tcp://localhost:7687`) **fails** for Neo4j BOLT protocol, causing HTTP 400 errors.

### ✅ The Solution: Cloudflare Access
Use `cloudflared access tcp` instead of `cloudflared tunnel` for reliable BOLT protocol connections.

### 1. Cloudflare Dashboard Configuration
Navigate to: **Zero Trust → Networks → Tunnels → Public Hostnames**

Add Public Hostname:
- **Type**: TCP
- **Hostname**: `neo4j-bolt.jeelidev.uk` (or your domain)
- **Service**: `tcp://localhost:7687`

### 2. Local Cloudflare Access Command
```bash
# Start tunnel for Neo4j BOLT
cloudflared access tcp --hostname neo4j-bolt.jeelidev.uk --url localhost:7687

# For multiple services (MySQL, PostgreSQL, SSH, etc.)
cloudflared access tcp --hostname mysql-server.jeelidev.uk --url localhost:3306
cloudflared access tcp --hostname postgres-server.jeelidev.uk --url localhost:5432
```

### 3. SSH Configuration (Optional but Recommended)
Add to `~/.ssh/config`:
```ssh
Host *.jeelidev.uk
  ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h
```

## 🛠️ Automated TCP Tunnels Service

### 📁 Included Scripts
This package includes automated tunnel management for **any TCP service**:

#### `cloudflare-tcp-tunnels.sh` - Main Script
```bash
# Start all configured tunnels
./cloudflare-tcp-tunnels.sh start

# Check tunnel status
./cloudflare-tcp-tunnels.sh status

# Add new tunnel
./cloudflare-tcp-tunnels.sh add my-service api.jeelidev.uk 3000

# List configured tunnels
./cloudflare-tcp-tunnels.sh list

# Remove existing tunnel
./cloudflare-tcp-tunnels.sh remove my-service

# Clean all tunnels (resets configuration)
./cloudflare-tcp-tunnels.sh clean

# Stop all tunnels
./cloudflare-tcp-tunnels.sh stop
```

#### Pre-configured Services:
- **Neo4j BOLT**: `neo4j-bolt.jeelidev.uk:7687`
- **Neo4j Routing**: `neo4j-routing.jeelidev.uk:7688`
- **MySQL**: `mysql-server.jeelidev.uk:3306`
- **PostgreSQL**: `postgres-server.jeelidev.uk:5432`
- **SSH**: `ssh-server.jeelidev.uk:22`
- **Redis**: `redis-server.jeelidev.uk:6379`
- **MongoDB**: `mongodb-server.jeelidev.uk:27017`
- **Custom Services**: Easily add more with `add` command

#### `cloudflare-tcp-tunnels.service` - Systemd Service
```bash
# Install for automatic startup on boot
sudo cp cloudflare-tcp-tunnels.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable cloudflare-tcp-tunnels.service
sudo systemctl start cloudflare-tcp-tunnels.service
```

## 🗄️ Neo4j Setup

### Working setup: DozerDB with GDS Plugin

For the database, use DozerDB with the Graph Data Science plug-in, GDS is not only recommended but necessary:

For current installation instructions, see: https://dozerdb.org/

Example setup:
```bash
# Run DozerDB container with latest version
docker run \
    -p 7474:7474 -p 7687:7687 \
    -v $HOME/neo4j/data:/data \
    -v $HOME/neo4j/logs:/logs \
    -v $HOME/neo4j/plugins:/plugins \
    --env NEO4J_AUTH=neo4j/password \
    --env NEO4J_dbms_security_procedures_unrestricted='gds.*' \
    graphstack/dozerdb:latest

# Install GDS plugin - see dozerdb.org for current instructions

# Verify GDS plugin works
# In Neo4j Browser (http://localhost:7474):
# RETURN gds.similarity.cosine([1,2,3], [2,3,4]) as similarity
```

### Remote Neo4j with Cloudflare Access
For remote Neo4j servers, use Cloudflare Access instead of traditional tunneling:

```bash
# On remote server: configure Zero Trust hostname
# On local machine: start access tunnel
cloudflared access tcp --hostname neo4j-remote.jeelidev.uk --url localhost:7687

# Connect Neo4j Browser to: bolt://localhost:7687
# MCP connects through localhost proxy
```

## 🛠️ Unified Tools

The server provides **4 unified MCP tools** that integrate automatically with Claude:

- `memory_store` - Create memories with observations and immediate relations in ONE operation
- `memory_find` - Unified search/retrieval with semantic search, direct ID lookup, date filtering, and graph traversal
- `memory_modify` - Comprehensive modification operations (update, delete, observations, relations)
- `database_switch` - Switch database context for isolated environments

## 📊 Memory Structure

```json
{
  "id": "dZ$abc123",
  "name": "Project Alpha",
  "memoryType": "project",
  "metadata": {"status": "active", "priority": "high"},
  "observations": [
    {"id": "dZ$obs456", "content": "Started development", "createdAt": "2025-06-08T10:00:00Z"}
  ],
  "related": {
    "ancestors": [{"id": "dZ$def789", "name": "Initiative", "relation": "PART_OF", "distance": 1}],
    "descendants": [{"id": "dZ$ghi012", "name": "Task", "relation": "INCLUDES", "distance": 1}]
  }
}
```

## 🎯 System Prompt

### The simplest use of the memory tool, the following usually is more than enough.

```
## Memory Tool Usage
- Store all memory for this project in database: 'project-database-name'
- Use MCP memory tools exclusively for storing project-related information
- Begin each session by:
  1. Switching to this project's database
  2. Searching memory for data relevant to the user's prompt
```

## 🔧 Troubleshooting

### Cloudflare Access Issues
**❌ HTTP 400 Error with Traditional Tunneling:**
```bash
# WRONG - This causes HTTP 400 errors
cloudflared tunnel --url tcp://localhost:7687

# CORRECT - Use Cloudflare Access
cloudflared access tcp --hostname neo4j-bolt.jeelidev.uk --url localhost:7687
```

**✅ Connection Verification:**
```bash
# Verify tunnel is working
netcat -zv localhost 7687
# Should show: Connection to localhost port 7687 [tcp/*] succeeded!
```

### Vector Search Issues:
- Check logs for `[VectorSearch] GDS Plugin detected`
- GDS Plugin requires DozerDB setup (see Neo4j Setup section)

### Connection Issues:
- Verify Neo4j is running: `docker ps`
- Test connection: `curl http://localhost:7474`
- Check credentials in environment variables
- Ensure Cloudflare Access tunnels are running

## 📚 Cloudflare Access Commands Reference

### Supported Protocols:
```bash
# TCP Services (Neo4j, MySQL, PostgreSQL, etc.)
cloudflared access tcp --hostname service.domain.com --url localhost:PORT

# SSH Services
cloudflared access ssh --hostname ssh.domain.com

# HTTP/HTTPS Services
cloudflared access https://app.domain.com

# RDP (Windows Remote Desktop)
cloudflared access rdp --hostname rdp.domain.com --local-port 3389

# VNC
cloudflared access vnc --hostname vnc.domain.com --local-port 5900
```

## 🚀 Production Deployment

### For Production Use:
1. **Install systemd service** for automatic tunnel startup
2. **Configure proper SSL certificates** in Cloudflare Zero Trust
3. **Set up access policies** for additional security
4. **Monitor tunnel health** with the provided status command
5. **Use environment variables** for sensitive configuration

## 📄 License

MIT

## 🤝 Contributing

This is a personal fork enhanced for Cloudflare Access compatibility. Original project by sylweriusz.

### Key Enhancements in This Fork:
- ✅ **Cloudflare Access TCP compatibility**
- ✅ **Enhanced error logging for tunneling issues**
- ✅ **Automated tunnel management scripts**
- ✅ **Production-ready systemd service**
- ✅ **Comprehensive documentation**