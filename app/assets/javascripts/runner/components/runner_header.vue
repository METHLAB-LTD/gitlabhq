<script>
import { GlSprintf } from '@gitlab/ui';
import { sprintf } from '~/locale';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { I18N_DETAILS_TITLE } from '../constants';
import RunnerTypeBadge from './runner_type_badge.vue';
import RunnerStatusBadge from './runner_status_badge.vue';

export default {
  components: {
    GlSprintf,
    TimeAgo,
    RunnerTypeBadge,
    RunnerStatusBadge,
  },
  props: {
    runner: {
      type: Object,
      required: true,
    },
  },
  computed: {
    paused() {
      return !this.runner.active;
    },
    heading() {
      const id = getIdFromGraphQLId(this.runner.id);
      return sprintf(I18N_DETAILS_TITLE, { runner_id: id });
    },
  },
};
</script>
<template>
  <div class="gl-py-5 gl-border-b-1 gl-border-b-solid gl-border-b-gray-100">
    <runner-status-badge :runner="runner" />
    <runner-type-badge v-if="runner" :type="runner.runnerType" />
    <template v-if="runner.createdAt">
      <gl-sprintf :message="__('%{runner} created %{timeago}')">
        <template #runner>
          <strong>{{ heading }}</strong>
        </template>
        <template #timeago>
          <time-ago :time="runner.createdAt" />
        </template>
      </gl-sprintf>
    </template>
    <template v-else>
      <strong>{{ heading }}</strong>
    </template>
  </div>
</template>
