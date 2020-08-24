import { inactiveId } from '~/boards/constants';

export default () => ({
  endpoints: {},
  boardType: null,
  isShowingLabels: true,
  activeId: inactiveId,
  boardLists: [],
  issuesByListId: {},
  isLoadingIssues: false,
  error: undefined,
  // TODO: remove after ce/ee split of board_content.vue
  isShowingEpicsSwimlanes: false,
});
