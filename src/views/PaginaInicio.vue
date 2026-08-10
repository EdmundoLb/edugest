<script setup>
const features = [
  {
    number: '01',
    title: 'Control de Asistencia',
    desc: 'Registro preciso de entrada y salida de alumnos con seguimiento en tiempo real de ausencias y retardos.',
    icon: 'check',
  },
  {
    number: '02',
    title: 'Gestión de Alumnos',
    desc: 'Perfiles completos con datos de contacto, matrícula, horarios y expediente académico centralizado.',
    icon: 'users',
  },
  {
    number: '03',
    title: 'Reportes Automáticos',
    desc: 'Estadísticas de asistencia, exportación de datos y generación de reportes para la toma de decisiones.',
    icon: 'chart',
  },
]
</script>

<template>
  <div class="landing">
    <section class="hero">
      <div class="hero-grid" />
      <div class="hero-glow" />
      <div class="hero-content">
        <div class="hero-badge">Plataforma de Gestión Académico</div>
        <h1 class="hero-title">Centro Cultural Gymmart</h1>
        <p class="hero-subtitle">
          Control de asistencia inteligente y administración integral<br />
          para instituciones educativas modernas.
        </p>
      </div>
    </section>

    <section class="features">
      <div class="features-inner">
        <div class="features-header">
          <span class="features-label">Funcionalidades</span>
          <h2 class="section-title">Todo lo que necesitas,<br />en un solo lugar</h2>
        </div>
        <div class="features-list">
          <div v-for="feat in features" :key="feat.number" class="feature-card">
            <div class="feature-number">{{ feat.number }}</div>
            <div class="feature-body">
              <div class="feature-icon">
                <svg v-if="feat.icon === 'check'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                  <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2" />
                  <rect x="9" y="3" width="6" height="4" rx="1" />
                  <path d="M9 14l2 2 4-4" />
                </svg>
                <svg v-else-if="feat.icon === 'users'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                  <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" />
                  <circle cx="9" cy="7" r="4" />
                  <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75" />
                </svg>
                <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                  <path d="M18 20V10M12 20V4M6 20v-6" />
                </svg>
              </div>
              <h3 class="feature-title">{{ feat.title }}</h3>
              <p class="feature-desc">{{ feat.desc }}</p>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="quote">
      <div class="quote-inner">
        <div class="quote-line" />
        <p class="quote-text">
          Plataforma segura y confiable diseñada para modernizar<br />
          la gestión académica de tu institución educativa.
        </p>
        <div class="quote-line" />
      </div>
    </section>
  </div>
</template>

<style scoped>
.landing {
  background: #000000;
  color: #ffffff;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

/* ── Hero ── */

.hero {
  position: relative;
  min-height: calc(100vh - 73px);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  background: linear-gradient(135deg, #000000 0%, #022451 50%, #004aad 100%);
  padding-top: 73px;
}

.hero-grid {
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgba(255, 255, 255, 0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.03) 1px, transparent 1px);
  background-size: 60px 60px;
  mask-image: radial-gradient(ellipse 70% 60% at 50% 40%, black 30%, transparent 70%);
  -webkit-mask-image: radial-gradient(ellipse 70% 60% at 50% 40%, black 30%, transparent 70%);
}

.hero-glow {
  position: absolute;
  width: 600px;
  height: 600px;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -55%);
  background: radial-gradient(circle, rgba(0, 74, 173, 0.15), transparent 60%);
  pointer-events: none;
}

.hero-content {
  position: relative;
  text-align: center;
  padding: 2rem;
  max-width: 680px;
}

.hero-badge {
  display: inline-block;
  padding: 0.375rem 1rem;
  background: rgba(0, 74, 173, 0.2);
  border: 1px solid rgba(0, 74, 173, 0.4);
  border-radius: 999px;
  font-size: 0.75rem;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: #6ea8fe;
  font-weight: 500;
  margin-bottom: 2rem;
}

.hero-title {
  font-size: 4rem;
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 1.05;
  color: #ffffff;
  margin-bottom: 1.5rem;
}

.hero-subtitle {
  font-size: 1.0625rem;
  line-height: 1.7;
  color: rgba(255, 255, 255, 0.6);
}

.features {
  background: #000000;
  padding: 7rem 2rem;
}

.features-inner {
  max-width: 960px;
  margin: 0 auto;
}

.features-header {
  text-align: center;
  margin-bottom: 4rem;
}

.features-label {
  display: inline-block;
  font-size: 0.6875rem;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: #004aad;
  font-weight: 600;
  margin-bottom: 1rem;
}

.section-title {
  font-size: 2.25rem;
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1.2;
  color: #ffffff;
}

.features-list {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1.5rem;
}

.feature-card {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding: 2rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 16px;
  transition: all 0.3s ease;
}

.feature-card:hover {
  transform: translateY(-4px);
  background: rgba(255, 255, 255, 0.06);
  border-color: rgba(0, 74, 173, 0.4);
}

.feature-number {
  font-size: 0.6875rem;
  font-weight: 600;
  color: #004aad;
  letter-spacing: 0.04em;
}

.feature-body {
  flex: 1;
}

.feature-icon {
  width: 44px;
  height: 44px;
  padding: 10px;
  background: rgba(0, 74, 173, 0.15);
  border: none;
  border-radius: 12px;
  margin-bottom: 1rem;
  color: #6ea8fe;
}

.feature-icon svg {
  width: 100%;
  height: 100%;
}

.feature-title {
  font-size: 1.0625rem;
  font-weight: 600;
  color: #ffffff;
  margin-bottom: 0.5rem;
  letter-spacing: -0.01em;
}

.feature-desc {
  font-size: 0.875rem;
  line-height: 1.65;
  color: rgba(255, 255, 255, 0.5);
  max-width: 520px;
}

/* ── Quote ── */

.quote {
  background: #022451;
  padding: 5rem 2rem;
}

.quote-inner {
  max-width: 640px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  gap: 2rem;
}

.quote-line {
  flex: 1;
  height: 1px;
  background: #004aad;
}

.quote-text {
  font-size: 1.0625rem;
  line-height: 1.7;
  color: #ffffff;
  text-align: center;
  font-weight: 500;
}

/* ── Responsive ── */

@media (max-width: 768px) {
  .hero-title {
    font-size: 2.5rem;
  }

  .hero-subtitle {
    font-size: 0.9375rem;
  }

  .hero-subtitle br {
    display: none;
  }

  .features {
    padding: 4rem 1.25rem;
  }

  .features-list {
    grid-template-columns: 1fr;
    gap: 1rem;
  }

  .feature-card {
    padding: 1.5rem;
  }

  .section-title {
    font-size: 1.625rem;
  }

  .section-title br {
    display: none;
  }

  .quote br {
    display: none;
  }

  .quote-inner {
    flex-direction: column;
    gap: 1rem;
  }

  .quote-line {
    width: 40px;
    flex: none;
  }
}

@media (max-width: 480px) {
  .hero-title {
    font-size: 2rem;
  }
}
</style>
