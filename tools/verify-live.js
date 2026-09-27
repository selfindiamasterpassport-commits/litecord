async (page) => {
  const res = await page.evaluate(() => {
    const external = [...document.querySelectorAll('link[href^="http"]')]
      .map(l => new URL(l.href).host);
    const requests = performance.getEntriesByType('resource')
      .map(r => new URL(r.name).host);
    return {
      title: document.title,
      bodyFont: getComputedStyle(document.body).fontFamily,
      interLoaded: document.fonts.check('700 16px Inter'),
      monoLoaded: document.fonts.check('400 12px "JetBrains Mono"'),
      fontFaceCount: document.fonts.size,
      externalHostsInHtml: external,
      distinctHostsRequested: [...new Set(requests)],
    };
  });
  return JSON.stringify(res, null, 2);
}
