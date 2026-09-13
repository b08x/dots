---
promptId: generateHeading
name: 📌 Generate Heading from Selection
description: Generate a concise and informative heading for the selected text
tags:
  - writing
  - editing
version: 0.0.1
mode: replace
---
Generate a concise and informative heading for the provided text. Read the text carefully, identify the main topic or theme, and craft a heading that reflects it. Use strong verbs and specific keywords to make the heading engaging. Ensure the heading is grammatically correct and free of errors.

<instruction>
	<action>Generate Heading</action>
	<context>
		{{selection}}
	</context>
	<style>literal</style>
	<output>
	</output>
</instruction>
