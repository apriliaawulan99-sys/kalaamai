import { z } from "zod";
export const correctionResultSchema=z.object({
 original_text:z.string(),transcription_uncertain:z.boolean(),corrected_text:z.string(),natural_alternative:z.string().nullable(),overall_assessment:z.enum(["correct","needs_correction","uncertain"]),
 corrections:z.array(z.object({category:z.enum(["nahwu","shorof","balaghah"]),original_fragment:z.string(),corrected_fragment:z.string(),error_type:z.string(),explanation_id:z.string(),explanation_ar:z.string(),severity:z.enum(["minor","moderate","important"]),confidence:z.number().min(0).max(1)})),
 balaghah_feedback:z.string().nullable(),vocabulary_suggestions:z.array(z.object({arabic:z.string(),meaning_id:z.string(),example_ar:z.string()})),practice_exercise:z.object({prompt:z.string(),expected_answer:z.string()}).nullable()
});
export type CorrectionResult=z.infer<typeof correctionResultSchema>;
export const correctionJsonSchema={type:"object",additionalProperties:false,properties:{
 original_text:{type:"string"},transcription_uncertain:{type:"boolean"},corrected_text:{type:"string"},natural_alternative:{type:["string","null"]},overall_assessment:{type:"string",enum:["correct","needs_correction","uncertain"]},
 corrections:{type:"array",items:{type:"object",additionalProperties:false,properties:{category:{type:"string",enum:["nahwu","shorof","balaghah"]},original_fragment:{type:"string"},corrected_fragment:{type:"string"},error_type:{type:"string"},explanation_id:{type:"string"},explanation_ar:{type:"string"},severity:{type:"string",enum:["minor","moderate","important"]},confidence:{type:"number",minimum:0,maximum:1}},required:["category","original_fragment","corrected_fragment","error_type","explanation_id","explanation_ar","severity","confidence"]}},
 balaghah_feedback:{type:["string","null"]},vocabulary_suggestions:{type:"array",items:{type:"object",additionalProperties:false,properties:{arabic:{type:"string"},meaning_id:{type:"string"},example_ar:{type:"string"}},required:["arabic","meaning_id","example_ar"]}},
 practice_exercise:{type:["object","null"],additionalProperties:false,properties:{prompt:{type:"string"},expected_answer:{type:"string"}},required:["prompt","expected_answer"]}
},required:["original_text","transcription_uncertain","corrected_text","natural_alternative","overall_assessment","corrections","balaghah_feedback","vocabulary_suggestions","practice_exercise"]} as const;
