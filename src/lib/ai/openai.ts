import OpenAI from "openai";
export function getOpenAIClient(){const apiKey=process.env.OPENAI_API_KEY;if(!apiKey)throw new Error("OPENAI_API_KEY belum dikonfigurasi di environment server.");return new OpenAI({apiKey,timeout:45000,maxRetries:1})}
export function getTextModel(){return process.env.OPENAI_TEXT_MODEL||"gpt-4.1-mini"}
