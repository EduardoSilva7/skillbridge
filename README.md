
# SkillBridge — Futuro do Trabalho · Mapeamento de Competências

[![Java](https://img.shields.io/badge/Java-17-red)](https://adoptium.net/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.x-brightgreen)](https://spring.io/projects/spring-boot)
[![Build](https://img.shields.io/badge/CI-Azure%20Pipelines-blue)](#cicd-azure-pipelines)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**SkillBridge** é uma API REST pensada para o *Futuro do Trabalho*: permite cadastrar **pessoas**, **competências** e os **níveis** de cada pessoa em cada competência.  
O objetivo é facilitar **mapeamento de talentos**, **upskilling/reskilling** e **alocação** em projetos.

---

## ✨ Principais features
- CRUD de **Pessoas** (`/pessoas`) e **Competências** (`/competencias`)
- Relação **Pessoa–Competência** com **nível** (`/pessoa-competencias`)
- Persistência em **MySQL 8** (produção) e **H2 em memória** (testes)
- Pronto para **CI/CD no Azure Pipelines** (build, testes JUnit, artifact e deploy em **Azure Web App**)
- Scripts de **provisionamento PaaS** (Azure Web App + Azure Database for MySQL Flexible Server)

---

## 🧱 Arquitetura (macro)
```
Cliente → Azure Web App (Java 17) → Spring Boot API → Azure Database for MySQL Flexible Server
```

> Observabilidade: Web App Logs (nativo). App Insights (opcional).  
> CI/CD: Azure Pipelines (Build → Release).

---

## 🧩 Stack
- **Linguagem:** Java 17
- **Framework:** Spring Boot 3 (Web, Data JPA, Validation)
- **Banco:** MySQL 8 (prod), H2 (testes)
- **Build:** Maven
- **Cloud:** Azure Web App (Java), Azure Database for MySQL Flexible Server
- **DevOps:** Azure Repos/Boards/Pipelines (YAML)

---

## 📁 Estrutura do projeto
```
skillbridge/
 ├─ src/main/java/com/fiap/skillbridge
 │   ├─ controller/              # Controllers REST
 │   ├─ entity/                  # Entidades JPA
 │   ├─ repository/              # Repositórios JPA
 │   └─ SkillBridgeApplication.java
 ├─ src/main/resources
 │   ├─ application.properties   # Config (por env vars)
 │   └─ schema.sql               # DDL inicial
 ├─ src/test/...                 # Testes JUnit + H2
 ├─ scripts/
 │   ├─ script-infra-azure.sh    # Provisionamento Azure (Bash)
 │   ├─ script-infra-azure.ps1   # Provisionamento Azure (PowerShell)
 │   └─ script-bd.sql            # DDL exemplo
 ├─ azure-pipelines.yml          # CI/CD (YAML)
 ├─ pom.xml
 └─ README.md
```

---

## 🚀 Como executar localmente
### Pré-requisitos
- Java 17, Maven 3.9+
- MySQL 8 em execução (porta 3306) — **ou** ajuste a `SPRING_DATASOURCE_URL` para outro host/porta

### Credenciais (padrão local)
- **Usuário:** `fiapadmin`
- **Senha:** `Fiap@2tds`
- **Database:** `appdb` (criada automaticamente com `createDatabaseIfNotExist=true`)

### Rodar
```bash
mvn spring-boot:run
# app em http://localhost:8080
```

### Variáveis de ambiente (opcional)
```bash
export SPRING_DATASOURCE_URL='jdbc:mysql://localhost:3306/appdb?createDatabaseIfNotExist=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC'
export SPRING_DATASOURCE_USERNAME='fiapadmin'
export SPRING_DATASOURCE_PASSWORD='Fiap@2tds'
```

---

## 🛣️ Endpoints principais
### Pessoas
- `GET /pessoas`
- `POST /pessoas`  
  body:
  ```json
  { "nome": "Ana Silva", "email": "ana@exemplo.com" }
  ```
- `GET /pessoas/{id}` · `PUT /pessoas/{id}` · `DELETE /pessoas/{id}`

### Competências
- `GET /competencias`
- `POST /competencias`  
  body:
  ```json
  { "nome": "Java" }
  ```
- `GET /competencias/{id}` · `PUT /competencias/{id}` · `DELETE /competencias/{id}`

### Pessoa–Competência
- `GET /pessoa-competencias`
- `POST /pessoa-competencias`  
  body:
  ```json
  { "pessoaId": 1, "competenciaId": 2, "nivel": 4 }
  ```
- `GET /pessoa-competencias/pessoa/{pessoaId}/competencia/{competenciaId}`
- `DELETE /pessoa-competencias/pessoa/{pessoaId}/competencia/{competenciaId}`

> **Dica:** adicione o Spring Boot Actuator se quiser `GET /actuator/health` para checagens de vida.

---

## 🔬 Testes
- **Banco:** H2 em memória (modo MySQL)
- **Rodar testes:**
```bash
mvn -q -DskipTests=false test
```

---

## ☁️ Deploy em produção (Azure PaaS)
> PaaS puro: **sem containers**. Use os scripts na pasta `scripts/`.

### 1) Provisionamento rápido (Bash)
```bash
az login
az account set --subscription "<SUA_SUB>"
chmod +x scripts/script-infra-azure.sh
./scripts/script-infra-azure.sh
# imprime URL do Web App e FQDN do MySQL
```

### 2) App settings que o script configura
- `SPRING_PROFILES_ACTIVE=dev`
- `SPRING_DATASOURCE_URL=jdbc:mysql://<FQDN>:3306/appdb?...`
- `SPRING_DATASOURCE_USERNAME=fiapadmin`
- `SPRING_DATASOURCE_PASSWORD=Fiap@2tds`

> Ajuste o SKU/region caso queira outro custo/performance.

---

## 🔁 CI/CD (Azure Pipelines)
Arquivo **`azure-pipelines.yml`**:
- **Build**: `mvn clean verify` (publica JUnit + artefato .jar)
- **Release**: deploy automático no **Azure Web App (Java 17)** usando `AzureWebApp@1`

**Pré-configuração mínima**
- *Service connection:* `AZURE_SERVICE_CONNECTION` (Azure Resource Manager)
- *Variable Group (Library):*
  - `WEBAPP_NAME=gs2025-skillbridge-dev-api`
  - `SPRING_PROFILES_ACTIVE=dev`
  - `SPRING_DATASOURCE_URL` (saída do script com FQDN)
  - `SPRING_DATASOURCE_USERNAME=fiapadmin`
  - `SPRING_DATASOURCE_PASSWORD=Fiap@2tds`

---

## 📌 Roadmap (sugestões)
- Autenticação (JWT) e perfis (admin/gestor/colaborador)
- Paginação e filtros por competência/nível
- Observabilidade (App Insights) e métricas customizadas
- Versionamento de schema com Flyway

---

## 🤝 Contribuindo
1. Crie uma issue com o escopo
2. Faça uma branch a partir da issue (`feature/<id>-descricao`)
3. Abra um PR para `main` (CI precisa passar)

---

## 📝 Licença
Distribuído sob a licença **MIT**. Sinta-se livre para usar academicamente e comercialmente.

---

> _Gerado em 2025-11-07_
