# Using Talis with Skills

[简体中文](with-skills.md) | [English](with-skills.en.md)

Use Talis to organize the request, then hand the text to the AI tool that will complete the task. If the receiving tool has the matching skill installed, it can use that skill for writing, design, or research. If not, the request still works as ordinary text. Talis and those skills can be used independently.

| Task | Talis system template | Optional receiving skill |
|---|---|---|
| Explore a writing direction | Writing Partner: Define the Brief | 7viow-writing-partner |
| Revise existing prose | Writing Editor: Set Revision Boundaries | 7viow-writing-editor |
| Clarify presentation content | Presentation Writing: Define the Brief | 7viow-deck-writing-editor |
| Design an interface or flow | Interface Design: Define the Brief | 7viow-ux-ui-design |
| Review a real experience | UX Review: Define the Scope | 7viow-ux-review |
| Produce a presentation | Presentation Production: Hand Off the Final Brief | 7viow-presentation-production |
| Scope asset research | Asset Research: Define the Scope | 7viow-distressed-asset-investment |
| Turn research into a site | Research Website: Hand Off the Findings | 7viow-research-site-builder |

Whether a skill can be installed or invoked depends on its actual release state and the current host. Names in the templates describe a possible division of work; they do not mean the skill is installed.

## Complete Example

Suppose you are preparing an introduction for a Pomodoro product for university students. Start in Talis with:

> I want to write a product introduction but have not decided how to frame it. The product runs only on macOS and includes a 25-minute timer plus pause and resume. Do not add other features.

Use Grill-me to clarify the audience, use, and tone, then copy the request into an AI tool with Writing Partner to explore a direction. After choosing a direction, hand the text to Writing Editor for the actual revision. If you only need one sentence changed, do it in the current AI tool.

If the next task is a product page, provide the selected direction, product facts, current text, and allowed revision scope to UX/UI Design. When a focused experience review is needed, supply the real page or screenshots to UX Review.

## What to Preserve in a Handoff

Give the receiving tool the current material, target audience, source facts, confirmed decisions, allowed change scope, and expected result. When feedback arrives, use Talis to prepare the next request or save the recurring requirements as a personal template.

Provide attachments through the receiving tool's own attachment flow. Talis does not read files mentioned in text, transfer attachments, or invoke sibling skills for you.
