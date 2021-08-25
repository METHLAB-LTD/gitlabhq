import { markInputRule } from '@tiptap/core';
import { Superscript } from '@tiptap/extension-superscript';
import { markInputRegex, extractMarkAttributesFromMatch } from '../services/mark_utils';

export default Superscript.extend({
  addInputRules() {
    return [markInputRule(markInputRegex('sup'), this.type, extractMarkAttributesFromMatch)];
  },
});
