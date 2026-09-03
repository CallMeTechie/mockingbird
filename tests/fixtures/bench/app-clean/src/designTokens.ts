// Alias table -- deliberately not the literal CSS custom-property name, to
// test that the tokens check resolves an alias instead of grepping for the
// exact string "--color-accent".
export const designTokens = { accent: "var(--color-accent)" };
