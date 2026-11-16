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

const LEAVE_TYPE_LABELS = { casual: 'Casual', sick: 'Sick', annual: 'Annual', other: 'Other' };
const day = (d) => d.toISOString().slice(0, 10);

// Sent to the employee when a manager approves or rejects their leave request.
function leaveDecisionEmail({ name, email }, leave, reviewer) {
  const decision = leave.status === 'approved' ? 'approved' : 'rejected';
  const range = day(leave.startDate) === day(leave.endDate) ? day(leave.startDate) : `${day(leave.startDate)} to ${day(leave.endDate)}`;
  return {
    to: email,
    subject: `Your leave request was ${decision}`,
    text: [
      `Hi ${name},`,
      '',
      `Your ${LEAVE_TYPE_LABELS[leave.leaveType]} leave request for ${range} (${leave.days} working day${leave.days === 1 ? '' : 's'}) was ${decision} by ${reviewer.name}.`,
      ...(leave.reviewNote ? ['', `Note: ${leave.reviewNote}`] : []),
    ].join('\n'),
  };
}

module.exports = { passwordResetEmail, welcomeEmail, leaveDecisionEmail };
