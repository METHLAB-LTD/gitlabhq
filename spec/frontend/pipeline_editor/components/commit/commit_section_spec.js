import { mount } from '@vue/test-utils';
import { GlFormTextarea, GlFormInput, GlLoadingIcon } from '@gitlab/ui';
import CommitSection from '~/pipeline_editor/components/commit/commit_section.vue';
import CommitForm from '~/pipeline_editor/components/commit/commit_form.vue';
import { objectToQuery, redirectTo } from '~/lib/utils/url_utility';
import commitCreate from '~/pipeline_editor/graphql/mutations/commit_ci_file.mutation.graphql';

import { COMMIT_SUCCESS } from '~/pipeline_editor/constants';
import {
  mockCiConfigPath,
  mockCiYml,
  mockCommitSha,
  mockCommitNextSha,
  mockCommitMessage,
  mockDefaultBranch,
  mockProjectFullPath,
  mockNewMergeRequestPath,
} from '../../mock_data';

jest.mock('~/lib/utils/url_utility', () => ({
  redirectTo: jest.fn(),
  refreshCurrentPage: jest.fn(),
  objectToQuery: jest.requireActual('~/lib/utils/url_utility').objectToQuery,
  mergeUrlParams: jest.requireActual('~/lib/utils/url_utility').mergeUrlParams,
}));

const mockVariables = {
  projectPath: mockProjectFullPath,
  startBranch: mockDefaultBranch,
  message: mockCommitMessage,
  filePath: mockCiConfigPath,
  content: mockCiYml,
  lastCommitId: mockCommitSha,
};

const mockProvide = {
  ciConfigPath: mockCiConfigPath,
  defaultBranch: mockDefaultBranch,
  projectFullPath: mockProjectFullPath,
  newMergeRequestPath: mockNewMergeRequestPath,
};

describe('Pipeline Editor | Commit section', () => {
  let wrapper;
  let mockMutate;

  const defaultProps = { ciFileContent: mockCiYml };

  const createComponent = ({ props = {}, options = {}, provide = {} } = {}) => {
    mockMutate = jest.fn().mockResolvedValue({
      data: {
        commitCreate: {
          errors: [],
          commit: {
            sha: mockCommitNextSha,
          },
        },
      },
    });

    wrapper = mount(CommitSection, {
      propsData: { ...defaultProps, ...props },
      provide: { ...mockProvide, ...provide },
      data() {
        return {
          commitSha: mockCommitSha,
        };
      },
      mocks: {
        $apollo: {
          mutate: mockMutate,
        },
      },
      attachTo: document.body,
      ...options,
    });
  };

  const findCommitForm = () => wrapper.findComponent(CommitForm);
  const findCommitBtnLoadingIcon = () =>
    wrapper.find('[type="submit"]').findComponent(GlLoadingIcon);

  const submitCommit = async ({
    message = mockCommitMessage,
    branch = mockDefaultBranch,
    openMergeRequest = false,
  } = {}) => {
    await findCommitForm().findComponent(GlFormTextarea).setValue(message);
    await findCommitForm().findComponent(GlFormInput).setValue(branch);
    if (openMergeRequest) {
      await findCommitForm().find('[data-testid="new-mr-checkbox"]').setChecked(openMergeRequest);
    }
    await findCommitForm().find('[type="submit"]').trigger('click');
    // Simulate the write to local cache that occurs after a commit
    await wrapper.setData({ commitSha: mockCommitNextSha });
  };

  const cancelCommitForm = async () => {
    const findCancelBtn = () => wrapper.find('[type="reset"]');
    await findCancelBtn().trigger('click');
  };

  beforeEach(() => {
    createComponent();
  });

  afterEach(() => {
    mockMutate.mockReset();

    wrapper.destroy();
    wrapper = null;
  });

  describe('when the user commits changes to the current branch', () => {
    beforeEach(async () => {
      await submitCommit();
    });

    it('calls the mutation with the default branch', () => {
      expect(mockMutate).toHaveBeenCalledTimes(1);
      expect(mockMutate).toHaveBeenCalledWith({
        mutation: commitCreate,
        update: expect.any(Function),
        variables: {
          ...mockVariables,
          branch: mockDefaultBranch,
        },
      });
    });

    it('emits an event to communicate the commit was successful', () => {
      expect(wrapper.emitted('commit')).toHaveLength(1);
      expect(wrapper.emitted('commit')[0]).toEqual([{ type: COMMIT_SUCCESS }]);
    });

    it('shows no saving state', () => {
      expect(findCommitBtnLoadingIcon().exists()).toBe(false);
    });

    it('a second commit submits the latest sha, keeping the form updated', async () => {
      await submitCommit();

      expect(mockMutate).toHaveBeenCalledTimes(2);
      expect(mockMutate).toHaveBeenCalledWith({
        mutation: commitCreate,
        update: expect.any(Function),
        variables: {
          ...mockVariables,
          lastCommitId: mockCommitNextSha,
          branch: mockDefaultBranch,
        },
      });
    });
  });

  describe('when the user commits changes to a new branch', () => {
    const newBranch = 'new-branch';

    beforeEach(async () => {
      await submitCommit({
        branch: newBranch,
      });
    });

    it('calls the mutation with the new branch', () => {
      expect(mockMutate).toHaveBeenCalledWith({
        mutation: commitCreate,
        update: expect.any(Function),
        variables: {
          ...mockVariables,
          branch: newBranch,
        },
      });
    });
  });

  describe('when the user commits changes to open a new merge request', () => {
    const newBranch = 'new-branch';

    beforeEach(async () => {
      await submitCommit({
        branch: newBranch,
        openMergeRequest: true,
      });
    });

    it('redirects to the merge request page with source and target branches', () => {
      const branchesQuery = objectToQuery({
        'merge_request[source_branch]': newBranch,
        'merge_request[target_branch]': mockDefaultBranch,
      });

      expect(redirectTo).toHaveBeenCalledWith(`${mockNewMergeRequestPath}?${branchesQuery}`);
    });
  });

  describe('when the commit is ocurring', () => {
    it('shows a saving state', async () => {
      mockMutate.mockImplementationOnce(() => {
        expect(findCommitBtnLoadingIcon().exists()).toBe(true);
        return Promise.resolve();
      });

      await submitCommit({
        message: mockCommitMessage,
        branch: mockDefaultBranch,
        openMergeRequest: false,
      });
    });
  });

  describe('when the commit form is cancelled', () => {
    beforeEach(async () => {
      createComponent();
    });

    it('emits an event so that it cab be reseted', async () => {
      await cancelCommitForm();

      expect(wrapper.emitted('resetContent')).toHaveLength(1);
    });
  });
});