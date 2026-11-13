export type Scenario={id:string;slug?:string;title_id:string;title_ar:string;description:string;minimum_level_id?:string|null;is_published?:boolean;opening_message?:string};
export type ChatMessage={id:string;role:"user"|"assistant";content:string;created_at?:string};
