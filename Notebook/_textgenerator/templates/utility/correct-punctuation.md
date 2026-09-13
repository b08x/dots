---
promptId: punctuate
name: 🔧 Correct Punctuation
description: Correct errors in transcribed text, focusing on technical terms and specialized vocabulary
tags:
  - writing
  - editing
  - transcription
version: 0.0.1
mode: replace
---

<Instruction>
    <Task>Correct Transcribed Text</Task>

    <Objective>
        You are tasked with correcting transcribed text based on the provided context. Your goal is to identify and correct errors in the transcription, particularly focusing on technical terms, names, or specialized vocabulary that may have been misinterpreted during the transcription process.
    </Objective>

    <Input>
        <TranscribedText>{{selection}}</TranscribedText>
        <Context>{{highlights}}</Context>
    </Input>

    <Process>
        <Step>
            <Title>Review the Transcribed Text and Context</Title>
            <Details>Carefully read through the transcribed text and the context information.</Details>
        </Step>

        <Step>
            <Title>Identify Potential Errors</Title>
            <Details>
                <Point>Identify words or phrases in the transcribed text that seem out of place, misspelled, or inconsistent with the context provided.</Point>
            </Details>
        </Step>

        <Step>
            <Title>Evaluate and Correct</Title>
            <Details>
                <Point>Consider if there's a more appropriate word or phrase based on the context.</Point>
                <Point>Evaluate the likelihood that the original transcription was a misinterpretation of a technical term, name, or specialized vocabulary.</Point>
                <Point>Determine if a correction is necessary and appropriate.</Point>
            </Details>
        </Step>

        <Step>
            <Title>Make Confident Corrections</Title>
            <Details>
                <Point>The original transcription is likely incorrect.</Point>
                <Point>You have a high degree of certainty about the correct term based on the context.</Point>
                <Point>The correction significantly improves the accuracy and clarity of the text.</Point>
            </Details>
        </Step>
        <Step>
            <Title>Exercise Caution</Title>
            <Details>
                <Point>Avoid changes when unsure about the correct term.</Point>
                <Point>Be mindful that the original text could be correct in a context you're not aware of.</Point>
                <Point>Refrain from corrections that do not substantially improve accuracy or clarity.</Point>
            </Details>
        </Step>
    </Process>

    <ResponseFormat>
        <Corrections>
            <Example>
                <Original>[original text]</Original>
                <Correction>[corrected text]</Correction>
                <Reason>[brief explanation for the correction]</Reason>
            </Example>
        </Corrections>
        <CorrectedText>Full corrected version of the transcribed text, organized into clear logical paragraphs</CorrectedText>
	        
    </ResponseFormat>
</Instruction>
