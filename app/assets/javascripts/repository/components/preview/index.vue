<script>
import { GlIcon, GlLink, GlLoadingIcon, GlSafeHtmlDirective as SafeHtml } from '@gitlab/ui';
import $ from 'jquery';
import '~/behaviors/markdown/render_gfm';
import { handleLocationHash } from '~/lib/utils/common_utils';
import readmeQuery from '../../queries/readme.query.graphql';

export default {
  apollo: {
    readme: {
      query: readmeQuery,
      variables() {
        return {
          url: this.blob.webPath,
        };
      },
      loadingKey: 'loading',
    },
  },
  components: {
    GlIcon,
    GlLink,
    GlLoadingIcon,
  },
  directives: {
    SafeHtml,
  },
  props: {
    blob: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      readme: null,
      loading: 0,
    };
  },
  watch: {
    readme(newVal) {
      if (newVal) {
        this.$nextTick(() => {
          handleLocationHash();
          $(this.$refs.readme).renderGFM();
        });
      }
    },
  },
  safeHtmlConfig: {
    ADD_TAGS: ['copy-code'],
  },
};
</script>

<template>
  <article class="file-holder limited-width-container readme-holder">
    <div class="js-file-title file-title-flex-parent">
      <div class="file-header-content">
        <gl-icon name="doc-text" />
        <gl-link :href="blob.webPath">
          <strong>{{ blob.name }}</strong>
        </gl-link>
      </div>
    </div>
    <div class="blob-viewer" data-qa-selector="blob_viewer_content" itemprop="about">
      <gl-loading-icon v-if="loading > 0" size="md" color="dark" class="my-4 mx-auto" />
      <div
        v-else-if="readme"
        ref="readme"
        v-safe-html:[$options.safeHtmlConfig]="readme.html"
      ></div>
    </div>
  </article>
</template>
