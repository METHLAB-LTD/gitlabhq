<script>
import RegistrySearch from '~/vue_shared/components/registry/registry_search.vue';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import { extractFilterAndSorting, getQueryParams } from '~/packages_and_registries/shared/utils';

export default {
  components: { RegistrySearch, UrlSync },
  props: {
    sortableFields: {
      type: Array,
      required: true,
    },
    defaultOrder: {
      type: String,
      required: true,
    },
    defaultSort: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      filters: [],
      sorting: {
        orderBy: this.defaultOrder,
        sort: this.defaultSort,
      },
      mountRegistrySearch: false,
    };
  },
  computed: {
    parsedSorting() {
      const cleanOrderBy = this.sorting?.orderBy.replace('_at', '');
      return `${cleanOrderBy}_${this.sorting?.sort}`.toUpperCase();
    },
  },
  mounted() {
    const queryParams = getQueryParams(window.document.location.search);
    const { sorting, filters } = extractFilterAndSorting(queryParams);
    this.updateSorting(sorting);
    this.updateFilters(filters);
    this.mountRegistrySearch = true;
    this.emitUpdate();
  },
  methods: {
    updateFilters(newValue) {
      this.filters = newValue;
    },
    updateSorting(newValue) {
      this.sorting = { ...this.sorting, ...newValue };
    },
    updateSortingAndEmitUpdate(newValue) {
      this.updateSorting(newValue);
      this.emitUpdate();
    },
    emitUpdate() {
      this.$emit('update', { sort: this.parsedSorting, filters: this.filters });
    },
  },
};
</script>

<template>
  <url-sync>
    <template #default="{ updateQuery }">
      <registry-search
        v-if="mountRegistrySearch"
        :filter="filters"
        :sorting="sorting"
        :tokens="$options.tokens"
        :sortable-fields="sortableFields"
        @sorting:changed="updateSortingAndEmitUpdate"
        @filter:changed="updateFilters"
        @filter:submit="emitUpdate"
        @query:changed="updateQuery"
      />
    </template>
  </url-sync>
</template>
