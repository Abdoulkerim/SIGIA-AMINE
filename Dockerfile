
# ============================================================
# SIGIA-AMINE — Dockerfile de production
# Next.js 16.4.3 / Node.js 26 / Supabase Cloud
# ============================================================

# Image commune
FROM node:26-bookworm-slim AS base

ENV NEXT_TELEMETRY_DISABLED=1

# ============================================================
# ETAPE 1 : Installation des dependances
# ============================================================
FROM base AS deps

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci


# ============================================================
# ETAPE 2 : Construction de Next.js
# ============================================================
FROM base AS builder

WORKDIR /app

# Variables publiques necessaires pendant next build
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY

ENV NEXT_PUBLIC_SUPABASE_URL=${NEXT_PUBLIC_SUPABASE_URL}
ENV NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=${NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY}

COPY --from=deps /app/node_modules ./node_modules

COPY . .

RUN npm run build


# ============================================================
# ETAPE 3 : Image finale de production
# ============================================================
FROM base AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Utilisateur non privilegie
RUN groupadd --system --gid 1001 nodejs \
    && useradd --system --uid 1001 --gid nodejs nextjs

# Fichiers publics
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

# Cache Next.js accessible en ecriture
RUN mkdir -p .next \
    && chown nextjs:nodejs .next

# Serveur Next.js autonome
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./

# Fichiers statiques
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Execution avec un utilisateur non privilegie
USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
