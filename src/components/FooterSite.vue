<template>
  <footer class="footer">
    <div class="footer-inner">
      <div class="footer-brand">
        <img src="@/images/edugest-logo.png" alt="EduGest" class="footer-logo logo-edugest" />
        <span>EduGest</span>
      </div>
      <p class="footer-copy">&copy; 2026 Centro Cultural Gymmart. Todos los derechos reservados.</p>
    </div>
  </footer>
</template>

<style scoped>
.footer {
  background: var(--surface);
  border-top: none;
}

.footer-inner {
  max-width: 960px;
  margin: 0 auto;
  padding: 2.5rem 2rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.75rem;
}

.footer-brand {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--text);
}

.footer-logo {
  width: 36px;
  height: 36px;
  object-fit: contain;
}

.footer-copy {
  font-size: 0.75rem;
  color: var(--text-muted);
  letter-spacing: 0.02em;
}
</style>
