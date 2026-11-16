// Plain-text email bodies. Kept separate from delivery so they are easy to restyle later.

function passwordResetEmail({ name, email }, code) {
  return {
    to: email,
    subject: 'Your ServiceHub password reset code',
    text: [
      `Hi ${name},`,
      '',
      `Your password reset code is: ${code}`,
      '',
      'Enter it in the ServiceHub app within 15 minutes to choose a new password.',
      "If you didn't request this, you can ignore this email; your password won't change.",
    ].join('\n'),
  };
}

function welcomeEmail({ name, email }, { employeeId }, code) {
  return {
    to: email,
    subject: 'Welcome to ServiceHub - set up your account',
    text: [
      `Hi ${name},`,
      '',
      `An account has been created for you on ServiceHub (Employee ID: ${employeeId}).`,
      '',
      `Your account setup code is: ${code}`,
      '',
      'To choose your password:',
      '  1. Open the ServiceHub app and tap "Forgot password?"',
      '  2. Tap "I already have a code"',
      `  3. Enter your email (${email}), this code and your new password`,
      '',
      'The code is valid for 3 days.',
    ].join('\n'),
  };
}

module.exports = { passwordResetEmail, welcomeEmail };
