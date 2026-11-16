// Time helpers for attendance. A "work date" is the calendar day in the company's time zone,
// stored as midnight UTC of that day (the same convention as task due dates).

// Wrapped in an object so tests can replace the current time with jest.spyOn(clock, 'now').
const clock = {
  now: () => new Date(),
};

function zonedParts(date, timeZone) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const get = (type) => Number(parts.find((p) => p.type === type).value);
  return { year: get('year'), month: get('month'), day: get('day'), hour: get('hour'), minute: get('minute') };
}

/** The calendar day `date` falls on in `timeZone`, as midnight UTC. */
function workDate(date, timeZone) {
  const p = zonedParts(date, timeZone);
  return new Date(Date.UTC(p.year, p.month - 1, p.day));
}

/** Minutes since local midnight in `timeZone` (e.g. 09:45 -> 585). */
function minutesOfDay(date, timeZone) {
  const p = zonedParts(date, timeZone);
  return p.hour * 60 + p.minute;
}

/** "09:30" -> 570 */
function parseHHmm(value) {
  const [h, m] = value.split(':').map(Number);
  return h * 60 + m;
}

module.exports = { clock, workDate, minutesOfDay, parseHHmm };
