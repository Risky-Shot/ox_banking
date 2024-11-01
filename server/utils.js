function getFormattedDates(date) {
  const rawDates = {
    from: new Date(date.from),
    to: new Date(date.to || date.from),
  };

  const formattedDates = {
    from: new Date(
      Date.UTC(rawDates.from.getFullYear(), rawDates.from.getMonth(), rawDates.from.getDate(), 0, 0, 0)
    ).toISOString(),
    to: new Date(
      Date.UTC(rawDates.to.getFullYear(), rawDates.to.getMonth(), rawDates.to.getDate(), 23, 59, 59)
    ).toISOString(),
  };

  return formattedDates;
}

exports('getFormattedDates', getFormattedDates);