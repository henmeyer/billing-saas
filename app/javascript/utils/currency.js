export function formatCurrency(amountCents, currency) {
  if (!currency) return `${amountCents / 100}`;

  const amount = amountCents / 100;
  return new Intl.NumberFormat("pt-BR", {
    style:    "currency",
    currency: currency.code,
  })
    .format(amount)
    .replace(/[A-Z]{3}/, currency.symbol);
}

export function formatAmount(amountCents, symbol) {
  const amount = (amountCents / 100).toFixed(2).replace(".", ",");
  return `${symbol} ${amount}`;
}
