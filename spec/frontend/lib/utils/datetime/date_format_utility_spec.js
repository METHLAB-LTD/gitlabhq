import * as utils from '~/lib/utils/datetime/date_format_utility';

describe('date_format_utility.js', () => {
  describe('padWithZeros', () => {
    it.each`
      input    | output
      ${0}     | ${'00'}
      ${'1'}   | ${'01'}
      ${'10'}  | ${'10'}
      ${'100'} | ${'100'}
      ${100}   | ${'100'}
      ${'a'}   | ${'0a'}
      ${'foo'} | ${'foo'}
    `('properly pads $input to match $output', ({ input, output }) => {
      expect(utils.padWithZeros(input)).toEqual([output]);
    });

    it('accepts multiple arguments', () => {
      expect(utils.padWithZeros(1, '2', 3)).toEqual(['01', '02', '03']);
    });

    it('returns an empty array provided no argument', () => {
      expect(utils.padWithZeros()).toEqual([]);
    });
  });

  describe('stripTimezoneFromISODate', () => {
    it.each`
      input                          | expectedOutput
      ${'2021-08-16T00:00:00Z'}      | ${'2021-08-16T00:00:00'}
      ${'2021-08-16T10:30:00+02:00'} | ${'2021-08-16T10:30:00'}
      ${'2021-08-16T10:30:00-05:30'} | ${'2021-08-16T10:30:00'}
    `('returns $expectedOutput when given $input', ({ input, expectedOutput }) => {
      expect(utils.stripTimezoneFromISODate(input)).toBe(expectedOutput);
    });

    it('returns null if date is invalid', () => {
      expect(utils.stripTimezoneFromISODate('Invalid date')).toBe(null);
    });
  });

  describe('dateToYearMonthDate', () => {
    it.each`
      date                      | expectedOutput
      ${new Date('2021-08-05')} | ${{ year: '2021', month: '08', day: '05' }}
      ${new Date('2021-12-24')} | ${{ year: '2021', month: '12', day: '24' }}
    `('returns $expectedOutput provided $date', ({ date, expectedOutput }) => {
      expect(utils.dateToYearMonthDate(date)).toEqual(expectedOutput);
    });

    it('throws provided an invalid date', () => {
      expect(() => utils.dateToYearMonthDate('Invalid date')).toThrow(
        'Argument should be a Date instance',
      );
    });
  });

  describe('timeToHoursMinutes', () => {
    it.each`
      time       | expectedOutput
      ${'23:12'} | ${{ hours: '23', minutes: '12' }}
      ${'23:12'} | ${{ hours: '23', minutes: '12' }}
    `('returns $expectedOutput provided $time', ({ time, expectedOutput }) => {
      expect(utils.timeToHoursMinutes(time)).toEqual(expectedOutput);
    });

    it('throws provided an invalid time', () => {
      expect(() => utils.timeToHoursMinutes('Invalid time')).toThrow('Invalid time provided');
    });
  });

  describe('dateAndTimeToUTCString', () => {
    it('computes the date properly', () => {
      expect(utils.dateAndTimeToUTCString(new Date('2021-08-16'), '10:00')).toBe(
        '2021-08-16T10:00:00.000Z',
      );
    });

    it('computes the date properly with an offset', () => {
      expect(utils.dateAndTimeToUTCString(new Date('2021-08-16'), '10:00', '-04:00')).toBe(
        '2021-08-16T14:00:00.000Z',
      );
    });

    it('throws if date in invalid', () => {
      expect(() => utils.dateAndTimeToUTCString('Invalid date', '10:00')).toThrow(
        'Argument should be a Date instance',
      );
    });

    it('throws if time in invalid', () => {
      expect(() => utils.dateAndTimeToUTCString(new Date('2021-08-16'), '')).toThrow(
        'Invalid time provided',
      );
    });

    it('throws if offset is invalid', () => {
      expect(() =>
        utils.dateAndTimeToUTCString(new Date('2021-08-16'), '10:00', 'not an offset'),
      ).toThrow('Invalid time value');
    });
  });

  describe('dateToTimeInputValue', () => {
    it.each`
      input                                        | expectedOutput
      ${new Date('2021-08-16T10:00:00.000Z')}      | ${'10:00'}
      ${new Date('2021-08-16T22:30:00.000Z')}      | ${'22:30'}
      ${new Date('2021-08-16T22:30:00.000-03:00')} | ${'01:30'}
    `('extracts $expectedOutput out of $input', ({ input, expectedOutput }) => {
      expect(utils.dateToTimeInputValue(input)).toBe(expectedOutput);
    });

    it('throws if date is invalid', () => {
      expect(() => utils.dateToTimeInputValue('Invalid date')).toThrow(
        'Argument should be a Date instance',
      );
    });
  });
});
