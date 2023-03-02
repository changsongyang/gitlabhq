import { GlIntersectionObserver } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import Category from '~/emoji/components/category.vue';
import EmojiGroup from '~/emoji/components/emoji_group.vue';

let wrapper;
function factory(propsData = {}) {
  wrapper = shallowMount(Category, { propsData });
}

const triggerGlIntersectionObserver = () => {
  wrapper.findComponent(GlIntersectionObserver).vm.$emit('appear');
  return nextTick();
};

describe('Emoji category component', () => {
  afterEach(() => {
    wrapper.destroy();
  });

  beforeEach(() => {
    factory({
      category: 'Activity',
      emojis: [['thumbsup'], ['thumbsdown']],
    });
  });

  it('renders emoji groups', () => {
    expect(wrapper.findAllComponents(EmojiGroup).length).toBe(2);
  });

  it('renders group', async () => {
    await triggerGlIntersectionObserver();

    expect(wrapper.findComponent(EmojiGroup).attributes('rendergroup')).toBe('true');
  });

  it('renders group on appear', async () => {
    await triggerGlIntersectionObserver();

    expect(wrapper.findComponent(EmojiGroup).attributes('rendergroup')).toBe('true');
  });

  it('emits appear event on appear', async () => {
    await triggerGlIntersectionObserver();

    expect(wrapper.emitted().appear[0]).toEqual(['Activity']);
  });
});
