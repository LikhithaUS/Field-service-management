const { config } = require('../config/env');

// Email delivery behind one function, so a real provider (Nodemailer SMTP, Resend, ...)
// can be dropped in later without touching controllers.
//
// Current transport: "console" - emails are printed to the server log.
// In tests, emails are collected in `outbox` so tests can read the codes.
const outbox = [];

async function sendEmail({ to, subject, text }) {
  const message = { to, subject, text, sentAt: new Date() };

  if (config.isTest) {
    outbox.push(message);
    return message;
  }

  console.log(
    [
      '',
      '==================== EMAIL (console transport) ====================',
      `To:      ${to}`,
      `Subject: ${subject}`,
      '',
      text,
      '===================================================================',
      '',
    ].join('\n')
  );
  return message;
}

module.exports = { sendEmail, outbox };
